// SPDX-License-Identifier: GPL-2.0-only
/*
 * Silicon Mitus SM5714 USB Type-C / USB-PD controller.
 *
 * This is a clean TCPM transport driver based on the register-level behaviour
 * documented by Samsung's GPL downstream driver.  The policy engine remains
 * Linux TCPM; none of Samsung's private notifier, battery or altmode framework
 * is copied here.
 */

#include <linux/bitops.h>
#include <linux/i2c.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/regmap.h>
#include <linux/usb/pd.h>
#include <linux/usb/tcpm.h>

#define SM5714_REG_INT1			0x01
#define SM5714_REG_MASK1		0x06
#define SM5714_REG_STATUS1		0x0b
#define  SM5714_INT1_VBUS_POK		BIT(0)
#define  SM5714_INT1_ATTACH		BIT(3)
#define  SM5714_INT1_DETACH		BIT(4)
#define  SM5714_INT2_SRC_ADV		BIT(4)
#define  SM5714_INT2_VBUS_0V		BIT(5)
#define  SM5714_INT4_RX_DONE		BIT(0)
#define  SM5714_INT4_TX_DONE		BIT(1)
#define  SM5714_INT4_TX_SOP_ERR	BIT(2)
#define  SM5714_INT4_PRL_RST_DONE	BIT(4)
#define  SM5714_INT4_HRST_RX		BIT(5)
#define  SM5714_INT4_HCRST_DONE	BIT(6)
#define  SM5714_INT4_TX_DISCARD	BIT(7)

#define SM5714_REG_CORR_CNTL4		0x23
#define SM5714_REG_CORR_CNTL5		0x24
#define SM5714_REG_CC_STATUS		0x28
#define  SM5714_CC_ATTACH_MASK		GENMASK(2, 0)
#define  SM5714_CC_ATTACH_SOURCE	1
#define  SM5714_CC_ATTACH_SINK		2
#define  SM5714_CC_ATTACH_AUDIO	3
#define  SM5714_CC_RP_MASK		GENMASK(4, 3)
#define  SM5714_CC_FLIPPED		BIT(5)
#define SM5714_REG_CC_CNTL1		0x29
#define SM5714_REG_CC_CNTL3		0x2b
#define SM5714_REG_CC_CNTL5		0x2d
#define SM5714_REG_PD_CNTL1		0x38
#define SM5714_REG_PD_CNTL2		0x39
#define SM5714_REG_PD_CNTL4		0x3b
#define  SM5714_PD_HARD_RESET		BIT(2)
#define SM5714_REG_RX_SRC		0x41
#define SM5714_REG_RX_HEADER		0x42
#define SM5714_REG_RX_PAYLOAD		0x44
#define SM5714_REG_RX_BUF		0x5e
#define SM5714_REG_TX_HEADER		0x60
#define SM5714_REG_TX_PAYLOAD		0x62
#define SM5714_REG_TX_REQ		0x7e
#define SM5714_REG_PD_STATE3		0xd8

/* Implemented by the companion charger/fuel-gauge driver on this board. */
int sm5714_battery_set_pd_contract(unsigned int mv, unsigned int ma);

struct sm5714_usbpd {
	struct device *dev;
	struct regmap *regmap;
	struct mutex lock;
	struct tcpc_dev tcpc;
	struct tcpm_port *port;
	struct fwnode_handle *connector;
	enum typec_cc_polarity polarity;
	unsigned int negotiated_mv;
	unsigned int negotiated_ma;
};

static const struct regmap_config sm5714_usbpd_regmap_config = {
	.reg_bits = 8,
	.val_bits = 8,
	.max_register = 0xff,
	.cache_type = REGCACHE_NONE,
};

static inline struct sm5714_usbpd *tcpc_to_sm5714(struct tcpc_dev *tcpc)
{
	return container_of(tcpc, struct sm5714_usbpd, tcpc);
}

static int sm5714_usbpd_init(struct tcpc_dev *tcpc)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int state3;
	u8 pending[5];
	static const u8 masks[5] = {
		0xe6, /* VBUS valid, attach and detach */
		0xcf, /* advertised current and VBUS 0 V */
		0xff,
		0x08, /* all PD transport events; bit 3 is unused */
		0xff,
	};
	int ret;

	mutex_lock(&sm->lock);

	/* Match the non-water-detection part of Samsung's register init. */
	ret = regmap_write(sm->regmap, SM5714_REG_CORR_CNTL5, 0x00);
	if (ret)
		goto out;
	ret = regmap_write(sm->regmap, SM5714_REG_CORR_CNTL4, 0x00);
	if (ret)
		goto out;
	ret = regmap_read(sm->regmap, SM5714_REG_PD_STATE3, &state3);
	if (ret)
		goto out;
	if (state3 & 0x06) {
		ret = regmap_write(sm->regmap, SM5714_REG_PD_CNTL4, 0x01);
		if (ret)
			goto out;
	}

	/* Reading the interrupt block clears stale edge latches. */
	ret = regmap_bulk_read(sm->regmap, SM5714_REG_INT1,
			       pending, sizeof(pending));
	if (ret)
		goto out;
	ret = regmap_bulk_write(sm->regmap, SM5714_REG_MASK1,
				masks, sizeof(masks));
out:
	mutex_unlock(&sm->lock);
	return ret;
}

static int sm5714_usbpd_get_vbus(struct tcpc_dev *tcpc)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int status;
	int ret;

	ret = regmap_read(sm->regmap, SM5714_REG_STATUS1, &status);
	if (ret)
		return ret;

	return !!(status & SM5714_INT1_VBUS_POK);
}

static enum typec_cc_status sm5714_usbpd_rp_status(unsigned int cc)
{
	switch (cc & SM5714_CC_RP_MASK) {
	case 0x08:
		return TYPEC_CC_RP_1_5;
	case 0x10:
	case 0x18:
		return TYPEC_CC_RP_3_0;
	default:
		return TYPEC_CC_RP_DEF;
	}
}

static int sm5714_usbpd_get_current_limit(struct tcpc_dev *tcpc)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int cc;
	int ret;

	ret = regmap_read(sm->regmap, SM5714_REG_CC_STATUS, &cc);
	if (ret)
		return ret;

	switch (sm5714_usbpd_rp_status(cc)) {
	case TYPEC_CC_RP_3_0:
		return 3000;
	case TYPEC_CC_RP_1_5:
		return 1500;
	default:
		return 500;
	}
}

static int sm5714_usbpd_get_cc(struct tcpc_dev *tcpc,
			       enum typec_cc_status *cc1,
			       enum typec_cc_status *cc2)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	enum typec_cc_status active = TYPEC_CC_OPEN;
	unsigned int cc;
	bool flipped;
	int ret;

	ret = regmap_read(sm->regmap, SM5714_REG_CC_STATUS, &cc);
	if (ret)
		return ret;

	switch (cc & SM5714_CC_ATTACH_MASK) {
	case SM5714_CC_ATTACH_SOURCE:
		active = sm5714_usbpd_rp_status(cc);
		break;
	case SM5714_CC_ATTACH_SINK:
		active = TYPEC_CC_RD;
		break;
	case SM5714_CC_ATTACH_AUDIO:
		*cc1 = TYPEC_CC_RA;
		*cc2 = TYPEC_CC_RA;
		return 0;
	default:
		break;
	}

	flipped = cc & SM5714_CC_FLIPPED;
	*cc1 = flipped ? TYPEC_CC_OPEN : active;
	*cc2 = flipped ? active : TYPEC_CC_OPEN;
	return 0;
}

static int sm5714_usbpd_set_cc(struct tcpc_dev *tcpc,
			       enum typec_cc_status cc)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int val;
	int ret;

	mutex_lock(&sm->lock);
	switch (cc) {
	case TYPEC_CC_OPEN:
		ret = regmap_read(sm->regmap, SM5714_REG_CC_CNTL3, &val);
		if (!ret)
			ret = regmap_write(sm->regmap, SM5714_REG_CC_CNTL3,
					   val | BIT(3));
		break;
	case TYPEC_CC_RD:
		/* Force the tablet into the attached sink/UFP state. */
		ret = regmap_write(sm->regmap, SM5714_REG_CC_CNTL1, 0x45);
		if (!ret)
			ret = regmap_write(sm->regmap, SM5714_REG_CC_CNTL3,
					   0x82);
		break;
	default:
		ret = -EOPNOTSUPP;
		break;
	}
	mutex_unlock(&sm->lock);

	return ret;
}

static int sm5714_usbpd_set_polarity(struct tcpc_dev *tcpc,
				     enum typec_cc_polarity polarity)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);

	sm->polarity = polarity;
	return 0;
}

static int sm5714_usbpd_set_vconn(struct tcpc_dev *tcpc, bool on)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	u8 val;

	if (!on)
		val = 0x18;
	else
		val = sm->polarity == TYPEC_POLARITY_CC1 ? 0x19 : 0x1a;

	return regmap_write(sm->regmap, SM5714_REG_CC_CNTL5, val);
}

static int sm5714_usbpd_set_vbus(struct tcpc_dev *tcpc, bool on, bool charge)
{
	/* This first mainline implementation is deliberately sink-only. */
	return on ? -EOPNOTSUPP : 0;
}

static int sm5714_usbpd_set_current_limit(struct tcpc_dev *tcpc,
					  u32 max_ma, u32 mv)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	int ret;

	ret = sm5714_battery_set_pd_contract(mv, max_ma);
	if (ret)
		return ret;

	sm->negotiated_mv = mv;
	sm->negotiated_ma = max_ma;
	dev_info(sm->dev, "USB-PD contract: %u mV, %u mA\n", mv, max_ma);
	return 0;
}

static int sm5714_usbpd_set_pd_rx(struct tcpc_dev *tcpc, bool on)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);

	return regmap_write(sm->regmap, SM5714_REG_PD_CNTL1,
			    on ? 0x08 : 0x00);
}

static int sm5714_usbpd_set_roles(struct tcpc_dev *tcpc, bool attached,
				  enum typec_role role,
				  enum typec_data_role data)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int val;
	int ret;

	ret = regmap_read(sm->regmap, SM5714_REG_PD_CNTL2, &val);
	if (ret)
		return ret;

	if (role == TYPEC_SOURCE)
		val |= BIT(1);
	else
		val &= ~BIT(1);
	if (data == TYPEC_HOST)
		val |= BIT(0);
	else
		val &= ~BIT(0);

	return regmap_write(sm->regmap, SM5714_REG_PD_CNTL2, val);
}

static int sm5714_usbpd_transmit(struct tcpc_dev *tcpc,
				 enum tcpm_transmit_type type,
				 const struct pd_message *msg,
				 unsigned int negotiated_rev)
{
	struct sm5714_usbpd *sm = tcpc_to_sm5714(tcpc);
	unsigned int count;
	u8 request;
	int ret;

	mutex_lock(&sm->lock);

	if (type == TCPC_TX_HARD_RESET) {
		ret = regmap_update_bits(sm->regmap, SM5714_REG_PD_CNTL4,
					 SM5714_PD_HARD_RESET,
					 SM5714_PD_HARD_RESET);
		goto out;
	}

	switch (type) {
	case TCPC_TX_SOP:
		request = 0x07;
		break;
	case TCPC_TX_SOP_PRIME:
		request = 0x17;
		break;
	case TCPC_TX_SOP_PRIME_PRIME:
		request = 0x27;
		break;
	default:
		ret = -EOPNOTSUPP;
		goto out;
	}

	count = pd_header_cnt_le(msg->header);
	ret = regmap_bulk_write(sm->regmap, SM5714_REG_TX_HEADER,
				&msg->header, sizeof(msg->header));
	if (ret)
		goto out;
	if (count) {
		ret = regmap_bulk_write(sm->regmap, SM5714_REG_TX_PAYLOAD,
					msg->payload,
					count * sizeof(msg->payload[0]));
		if (ret)
			goto out;
	}
	ret = regmap_write(sm->regmap, SM5714_REG_TX_REQ, request);
out:
	mutex_unlock(&sm->lock);
	return ret;
}

static void sm5714_usbpd_receive(struct sm5714_usbpd *sm)
{
	struct pd_message msg = {};
	enum tcpm_transmit_type sop;
	unsigned int origin;
	unsigned int count;
	int ret;

	ret = regmap_bulk_read(sm->regmap, SM5714_REG_RX_HEADER,
			       &msg.header, sizeof(msg.header));
	if (ret)
		return;
	count = pd_header_cnt_le(msg.header);
	if (count > PD_MAX_PAYLOAD)
		goto acknowledge;
	if (count) {
		ret = regmap_bulk_read(sm->regmap, SM5714_REG_RX_PAYLOAD,
				       msg.payload,
				       count * sizeof(msg.payload[0]));
		if (ret)
			goto acknowledge;
	}
	ret = regmap_read(sm->regmap, SM5714_REG_RX_SRC, &origin);
	if (ret)
		goto acknowledge;

	switch (origin & 0x0f) {
	case 0:
		sop = TCPC_TX_SOP;
		break;
	case 1:
		sop = TCPC_TX_SOP_PRIME;
		break;
	case 2:
		sop = TCPC_TX_SOP_PRIME_PRIME;
		break;
	default:
		goto acknowledge;
	}
	tcpm_pd_receive(sm->port, &msg, sop);

acknowledge:
	regmap_write(sm->regmap, SM5714_REG_RX_BUF, 0x80);
}

static irqreturn_t sm5714_usbpd_irq(int irq, void *data)
{
	struct sm5714_usbpd *sm = data;
	u8 intr[5];
	int ret;

	mutex_lock(&sm->lock);
	ret = regmap_bulk_read(sm->regmap, SM5714_REG_INT1,
			       intr, sizeof(intr));
	if (ret) {
		mutex_unlock(&sm->lock);
		return IRQ_NONE;
	}

	if (intr[3] & SM5714_INT4_RX_DONE)
		sm5714_usbpd_receive(sm);
	if (intr[3] & SM5714_INT4_TX_DONE)
		tcpm_pd_transmit_complete(sm->port, TCPC_TX_SUCCESS);
	else if (intr[3] & SM5714_INT4_TX_DISCARD)
		tcpm_pd_transmit_complete(sm->port, TCPC_TX_DISCARDED);
	else if (intr[3] & SM5714_INT4_TX_SOP_ERR)
		tcpm_pd_transmit_complete(sm->port, TCPC_TX_FAILED);
	if (intr[3] & SM5714_INT4_HRST_RX)
		tcpm_pd_hard_reset(sm->port);

	mutex_unlock(&sm->lock);

	if (intr[0] & (SM5714_INT1_ATTACH | SM5714_INT1_DETACH) ||
	    intr[1] & SM5714_INT2_SRC_ADV)
		tcpm_cc_change(sm->port);
	if (intr[0] & SM5714_INT1_VBUS_POK ||
	    intr[1] & SM5714_INT2_VBUS_0V)
		tcpm_vbus_change(sm->port);

	return IRQ_HANDLED;
}

static int sm5714_usbpd_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct sm5714_usbpd *sm;
	int ret;

	sm = devm_kzalloc(dev, sizeof(*sm), GFP_KERNEL);
	if (!sm)
		return -ENOMEM;

	sm->dev = dev;
	sm->regmap = devm_regmap_init_i2c(client,
					  &sm5714_usbpd_regmap_config);
	if (IS_ERR(sm->regmap))
		return PTR_ERR(sm->regmap);
	mutex_init(&sm->lock);
	i2c_set_clientdata(client, sm);

	sm->connector = device_get_named_child_node(dev, "connector");
	if (!sm->connector)
		return dev_err_probe(dev, -EINVAL,
				     "missing usb-c-connector child\n");

	sm->tcpc.fwnode = sm->connector;
	sm->tcpc.init = sm5714_usbpd_init;
	sm->tcpc.get_vbus = sm5714_usbpd_get_vbus;
	sm->tcpc.get_current_limit = sm5714_usbpd_get_current_limit;
	sm->tcpc.set_cc = sm5714_usbpd_set_cc;
	sm->tcpc.get_cc = sm5714_usbpd_get_cc;
	sm->tcpc.set_polarity = sm5714_usbpd_set_polarity;
	sm->tcpc.set_vconn = sm5714_usbpd_set_vconn;
	sm->tcpc.set_vbus = sm5714_usbpd_set_vbus;
	sm->tcpc.set_current_limit = sm5714_usbpd_set_current_limit;
	sm->tcpc.set_pd_rx = sm5714_usbpd_set_pd_rx;
	sm->tcpc.set_roles = sm5714_usbpd_set_roles;
	sm->tcpc.pd_transmit = sm5714_usbpd_transmit;

	sm->port = tcpm_register_port(dev, &sm->tcpc);
	if (IS_ERR(sm->port)) {
		ret = PTR_ERR(sm->port);
		goto put_fwnode;
	}

	ret = devm_request_threaded_irq(dev, client->irq, NULL,
					sm5714_usbpd_irq,
					IRQF_ONESHOT | IRQF_TRIGGER_LOW,
					dev_name(dev), sm);
	if (ret)
		goto unregister_port;

	device_init_wakeup(dev, true);
	enable_irq_wake(client->irq);
	tcpm_cc_change(sm->port);
	tcpm_vbus_change(sm->port);
	dev_info(dev, "SM5714 USB Type-C/PD controller registered\n");
	return 0;

unregister_port:
	tcpm_unregister_port(sm->port);
put_fwnode:
	fwnode_handle_put(sm->connector);
	return ret;
}

static void sm5714_usbpd_remove(struct i2c_client *client)
{
	struct sm5714_usbpd *sm = i2c_get_clientdata(client);

	disable_irq_wake(client->irq);
	tcpm_unregister_port(sm->port);
	fwnode_handle_put(sm->connector);
}

static const struct of_device_id sm5714_usbpd_of_match[] = {
	{ .compatible = "siliconmitus,sm5714-usbpd" },
	{ }
};
MODULE_DEVICE_TABLE(of, sm5714_usbpd_of_match);

static struct i2c_driver sm5714_usbpd_driver = {
	.driver = {
		.name = "sm5714-usbpd",
		.of_match_table = sm5714_usbpd_of_match,
	},
	.probe = sm5714_usbpd_probe,
	.remove = sm5714_usbpd_remove,
};
module_i2c_driver(sm5714_usbpd_driver);

MODULE_DESCRIPTION("Silicon Mitus SM5714 USB Type-C and PD controller");
MODULE_LICENSE("GPL");
