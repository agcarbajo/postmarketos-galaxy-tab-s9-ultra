// SPDX-License-Identifier: GPL-2.0-only
/*
 * Silicon Mitus SM5714 charger + fuel gauge, as wired on the Samsung Galaxy
 * Tab S9 Ultra Wi-Fi (SM-X910).
 *
 * SM8550 boards normally report the battery through pmic_glink/qcom_battmgr,
 * but that path needs a "charger_pd" protection domain on the ADSP and this
 * device's firmware ships none (only root_pd, sensor_pd, audio_pd and the CDSP
 * root_pd).  Samsung drives the SM5714 from the AP instead, so do the same.
 *
 * The chip answers on three I2C addresses on the same bus: 0x49 for the
 * charger block (8-bit registers), 0x71 for the fuel gauge (16-bit registers,
 * with the interesting values behind an SRAM read window) and 0x25 for the
 * MUIC.  This driver binds the charger address and creates a dummy client for
 * the fuel gauge.
 *
 * It is deliberately read-only: charging is already set up by the boot chain
 * and by the charger's own autonomous logic, and mis-programming a charger is
 * not a mistake worth risking on real hardware.  Register layout and the
 * fixed-point conversions come from Samsung's downstream sm5714_fuelgauge.c
 * and sm5714_charger.c.
 */

#include <linux/bitops.h>
#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/power_supply.h>
#include <linux/workqueue.h>

#define SM5714_FG_I2C_ADDR		0x71

/* Charger block (8-bit registers, at the address this driver binds). */
#define SM5714_CHG_REG_STATUS1		0x0d
#define  SM5714_CHG_STATUS1_VBUS_POK	BIT(0)
#define SM5714_CHG_REG_STATUS2		0x0e
#define  SM5714_CHG_STATUS2_CHG_ON	BIT(3)
#define  SM5714_CHG_STATUS2_TOPOFF	BIT(5)
#define SM5714_CHG_REG_DEVICEID		0x50

/* Fuel gauge block (16-bit registers, at SM5714_FG_I2C_ADDR). */
#define SM5714_FG_REG_DEVICE_ID		0x00
#define SM5714_FG_REG_SRAM_RADDR	0x8c
#define SM5714_FG_REG_SRAM_RDATA	0x8d

/* Fuel gauge SRAM window addresses. */
#define SM5714_FG_SRAM_SOC		0x00
#define SM5714_FG_SRAM_OCV		0x01
#define SM5714_FG_SRAM_VBAT		0x03
#define SM5714_FG_SRAM_CURRENT		0x05
#define SM5714_FG_SRAM_TEMPERATURE	0x07
#define SM5714_FG_SRAM_VBAT_AVG		0x08
#define SM5714_FG_SRAM_CURRENT_AVG	0x09

#define SM5714_POLL_INTERVAL_MS		10000

struct sm5714_battery {
	struct device *dev;
	struct i2c_client *chg;
	struct i2c_client *fg;
	/* Serialises the two-step SRAM read window on the fuel gauge. */
	struct mutex sram_lock;
	struct power_supply *psy_bat;
	struct power_supply *psy_usb;
	struct power_supply_battery_info *info;
	struct delayed_work poll_work;
	int last_status;
	int last_capacity;
	bool last_online;
};

/*
 * The fuel gauge exposes its measurements through an SRAM read window: point
 * RADDR at the word of interest, then read RDATA.
 */
static int sm5714_fg_read_sram(struct sm5714_battery *sm, u8 addr)
{
	int ret;

	mutex_lock(&sm->sram_lock);

	ret = i2c_smbus_write_word_data(sm->fg, SM5714_FG_REG_SRAM_RADDR, addr);
	if (ret < 0)
		goto out;

	ret = i2c_smbus_read_word_data(sm->fg, SM5714_FG_REG_SRAM_RDATA);
out:
	mutex_unlock(&sm->sram_lock);
	if (ret < 0)
		dev_dbg(sm->dev, "SRAM read 0x%02x failed: %d\n", addr, ret);
	return ret;
}

/*
 * Current and temperature are legitimately negative when the battery is
 * discharging or cold, so these helpers report the value through *val and keep
 * the return code purely for I/O errors.  Folding the two together would make a
 * discharging battery look like a failing I2C transfer.
 */

/* State of charge arrives as an unsigned Q8.8 percentage. */
static int sm5714_get_capacity(struct sm5714_battery *sm, int *val)
{
	int raw = sm5714_fg_read_sram(sm, SM5714_FG_SRAM_SOC);

	if (raw < 0)
		return raw;

	*val = clamp(((raw * 10) >> 8) / 10, 0, 100);
	return 0;
}

/* Battery voltage is offset from 2700 mV in units of 10/109 mV. */
static int sm5714_get_voltage(struct sm5714_battery *sm, u8 sram_addr, int *val)
{
	int raw = sm5714_fg_read_sram(sm, sram_addr);
	int mv;

	if (raw < 0)
		return raw;

	if (raw & 0x8000)
		mv = 2700 - (((raw & 0x7fff) * 10) / 109);
	else
		mv = ((raw * 10) / 109) + 2700;

	*val = mv * 1000;
	return 0;
}

static int sm5714_get_ocv(struct sm5714_battery *sm, int *val)
{
	int raw = sm5714_fg_read_sram(sm, SM5714_FG_SRAM_OCV);

	if (raw < 0)
		return raw;

	*val = ((raw * 1000) >> 11) * 1000;
	return 0;
}

/*
 * Current is a sign-magnitude value in units of 1/2044 A.  Bit 15 marks a
 * discharge, which matches the power supply class convention of negative
 * current flowing out of the battery.
 */
static int sm5714_get_current(struct sm5714_battery *sm, u8 sram_addr, int *val)
{
	int raw = sm5714_fg_read_sram(sm, sram_addr);
	int ma;

	if (raw < 0)
		return raw;

	ma = ((raw & 0x7fff) * 1000) / 2044;
	if (raw & 0x8000)
		ma = -ma;

	*val = ma * 1000;
	return 0;
}

static int sm5714_get_temp(struct sm5714_battery *sm, int *val)
{
	int raw = sm5714_fg_read_sram(sm, SM5714_FG_SRAM_TEMPERATURE);
	int temp;

	if (raw < 0)
		return raw;

	temp = (((raw & 0x7fff) * 10) * 2989) >> 11 >> 8;
	if (raw & 0x8000)
		temp = -temp;

	*val = temp;
	return 0;
}

static int sm5714_get_online(struct sm5714_battery *sm)
{
	int ret = i2c_smbus_read_byte_data(sm->chg, SM5714_CHG_REG_STATUS1);

	if (ret < 0)
		return ret;

	return !!(ret & SM5714_CHG_STATUS1_VBUS_POK);
}

static int sm5714_get_status(struct sm5714_battery *sm)
{
	int st1, st2;

	st1 = i2c_smbus_read_byte_data(sm->chg, SM5714_CHG_REG_STATUS1);
	if (st1 < 0)
		return st1;
	st2 = i2c_smbus_read_byte_data(sm->chg, SM5714_CHG_REG_STATUS2);
	if (st2 < 0)
		return st2;

	if (st2 & SM5714_CHG_STATUS2_TOPOFF)
		return POWER_SUPPLY_STATUS_FULL;
	if (st2 & SM5714_CHG_STATUS2_CHG_ON)
		return POWER_SUPPLY_STATUS_CHARGING;
	if (st1 & SM5714_CHG_STATUS1_VBUS_POK)
		return POWER_SUPPLY_STATUS_NOT_CHARGING;

	return POWER_SUPPLY_STATUS_DISCHARGING;
}

static int sm5714_bat_get_property(struct power_supply *psy,
				   enum power_supply_property psp,
				   union power_supply_propval *val)
{
	struct sm5714_battery *sm = power_supply_get_drvdata(psy);
	int ret;

	switch (psp) {
	case POWER_SUPPLY_PROP_STATUS:
		ret = sm5714_get_status(sm);
		if (ret < 0)
			return ret;
		val->intval = ret;
		return 0;
	case POWER_SUPPLY_PROP_PRESENT:
		val->intval = 1;
		return 0;
	case POWER_SUPPLY_PROP_TECHNOLOGY:
		val->intval = POWER_SUPPLY_TECHNOLOGY_LION;
		return 0;
	case POWER_SUPPLY_PROP_CAPACITY:
		ret = sm5714_get_capacity(sm, &val->intval);
		break;
	case POWER_SUPPLY_PROP_VOLTAGE_NOW:
		ret = sm5714_get_voltage(sm, SM5714_FG_SRAM_VBAT, &val->intval);
		break;
	case POWER_SUPPLY_PROP_VOLTAGE_AVG:
		ret = sm5714_get_voltage(sm, SM5714_FG_SRAM_VBAT_AVG,
					 &val->intval);
		break;
	case POWER_SUPPLY_PROP_VOLTAGE_OCV:
		ret = sm5714_get_ocv(sm, &val->intval);
		break;
	case POWER_SUPPLY_PROP_CURRENT_NOW:
		ret = sm5714_get_current(sm, SM5714_FG_SRAM_CURRENT,
					 &val->intval);
		break;
	case POWER_SUPPLY_PROP_CURRENT_AVG:
		ret = sm5714_get_current(sm, SM5714_FG_SRAM_CURRENT_AVG,
					 &val->intval);
		break;
	case POWER_SUPPLY_PROP_TEMP:
		ret = sm5714_get_temp(sm, &val->intval);
		break;
	case POWER_SUPPLY_PROP_CHARGE_FULL_DESIGN:
		if (!sm->info ||
		    sm->info->charge_full_design_uah < 0)
			return -ENODATA;
		val->intval = sm->info->charge_full_design_uah;
		return 0;
	case POWER_SUPPLY_PROP_VOLTAGE_MAX_DESIGN:
		if (!sm->info ||
		    sm->info->voltage_max_design_uv < 0)
			return -ENODATA;
		val->intval = sm->info->voltage_max_design_uv;
		return 0;
	case POWER_SUPPLY_PROP_VOLTAGE_MIN_DESIGN:
		if (!sm->info ||
		    sm->info->voltage_min_design_uv < 0)
			return -ENODATA;
		val->intval = sm->info->voltage_min_design_uv;
		return 0;
	default:
		return -EINVAL;
	}

	return ret;
}

static int sm5714_usb_get_property(struct power_supply *psy,
				   enum power_supply_property psp,
				   union power_supply_propval *val)
{
	struct sm5714_battery *sm = power_supply_get_drvdata(psy);
	int ret;

	switch (psp) {
	case POWER_SUPPLY_PROP_ONLINE:
		ret = sm5714_get_online(sm);
		break;
	default:
		return -EINVAL;
	}

	if (ret < 0)
		return ret;

	val->intval = ret;
	return 0;
}

static enum power_supply_property sm5714_bat_props[] = {
	POWER_SUPPLY_PROP_STATUS,
	POWER_SUPPLY_PROP_PRESENT,
	POWER_SUPPLY_PROP_TECHNOLOGY,
	POWER_SUPPLY_PROP_CAPACITY,
	POWER_SUPPLY_PROP_VOLTAGE_NOW,
	POWER_SUPPLY_PROP_VOLTAGE_AVG,
	POWER_SUPPLY_PROP_VOLTAGE_OCV,
	POWER_SUPPLY_PROP_VOLTAGE_MAX_DESIGN,
	POWER_SUPPLY_PROP_VOLTAGE_MIN_DESIGN,
	POWER_SUPPLY_PROP_CURRENT_NOW,
	POWER_SUPPLY_PROP_CURRENT_AVG,
	POWER_SUPPLY_PROP_CHARGE_FULL_DESIGN,
	POWER_SUPPLY_PROP_TEMP,
};

static enum power_supply_property sm5714_usb_props[] = {
	POWER_SUPPLY_PROP_ONLINE,
};

static const struct power_supply_desc sm5714_bat_desc = {
	.name		= "sm5714-battery",
	.type		= POWER_SUPPLY_TYPE_BATTERY,
	.properties	= sm5714_bat_props,
	.num_properties	= ARRAY_SIZE(sm5714_bat_props),
	.get_property	= sm5714_bat_get_property,
};

static const struct power_supply_desc sm5714_usb_desc = {
	.name		= "sm5714-usb",
	.type		= POWER_SUPPLY_TYPE_USB,
	.properties	= sm5714_usb_props,
	.num_properties	= ARRAY_SIZE(sm5714_usb_props),
	.get_property	= sm5714_usb_get_property,
};

/*
 * The charger's interrupt line is not wired up here, so poll the few values a
 * desktop actually reacts to and only wake userspace when one of them moves.
 */
static void sm5714_poll_work(struct work_struct *work)
{
	struct sm5714_battery *sm = container_of(to_delayed_work(work),
						 struct sm5714_battery,
						 poll_work);
	int status = sm5714_get_status(sm);
	int online = sm5714_get_online(sm);
	int capacity;

	if (sm5714_get_capacity(sm, &capacity))
		capacity = sm->last_capacity;

	if (status >= 0 &&
	    (status != sm->last_status || capacity != sm->last_capacity)) {
		sm->last_status = status;
		sm->last_capacity = capacity;
		power_supply_changed(sm->psy_bat);
	}

	if (online >= 0 && !!online != sm->last_online) {
		sm->last_online = online;
		power_supply_changed(sm->psy_usb);
	}

	schedule_delayed_work(&sm->poll_work,
			      msecs_to_jiffies(SM5714_POLL_INTERVAL_MS));
}

static void sm5714_cancel_poll(void *data)
{
	struct sm5714_battery *sm = data;

	cancel_delayed_work_sync(&sm->poll_work);
}

static int sm5714_probe(struct i2c_client *client)
{
	struct power_supply_config psy_cfg = {};
	struct device *dev = &client->dev;
	struct sm5714_battery *sm;
	int ret;

	if (!i2c_check_functionality(client->adapter,
				     I2C_FUNC_SMBUS_BYTE_DATA |
				     I2C_FUNC_SMBUS_WORD_DATA))
		return -EOPNOTSUPP;

	sm = devm_kzalloc(dev, sizeof(*sm), GFP_KERNEL);
	if (!sm)
		return -ENOMEM;

	sm->dev = dev;
	sm->chg = client;
	i2c_set_clientdata(client, sm);

	ret = devm_mutex_init(dev, &sm->sram_lock);
	if (ret)
		return ret;

	ret = i2c_smbus_read_byte_data(client, SM5714_CHG_REG_DEVICEID);
	if (ret < 0)
		return dev_err_probe(dev, ret, "no charger at 0x%02x\n",
				     client->addr);
	dev_info(dev, "SM5714 charger device id 0x%02x\n", ret);

	sm->fg = devm_i2c_new_dummy_device(dev, client->adapter,
					   SM5714_FG_I2C_ADDR);
	if (IS_ERR(sm->fg))
		return dev_err_probe(dev, PTR_ERR(sm->fg),
				     "cannot claim fuel gauge at 0x%02x\n",
				     SM5714_FG_I2C_ADDR);

	ret = i2c_smbus_read_word_data(sm->fg, SM5714_FG_REG_DEVICE_ID);
	if (ret < 0)
		return dev_err_probe(dev, ret, "no fuel gauge at 0x%02x\n",
				     SM5714_FG_I2C_ADDR);
	dev_info(dev, "SM5714 fuel gauge device id 0x%04x\n", ret);

	psy_cfg.drv_data = sm;
	psy_cfg.fwnode = dev_fwnode(dev);

	sm->psy_bat = devm_power_supply_register(dev, &sm5714_bat_desc,
						 &psy_cfg);
	if (IS_ERR(sm->psy_bat))
		return dev_err_probe(dev, PTR_ERR(sm->psy_bat),
				     "cannot register battery\n");

	sm->psy_usb = devm_power_supply_register(dev, &sm5714_usb_desc,
						 &psy_cfg);
	if (IS_ERR(sm->psy_usb))
		return dev_err_probe(dev, PTR_ERR(sm->psy_usb),
				     "cannot register charger\n");

	/* Design capacity is board data; absent monitored-battery, skip it. */
	if (power_supply_get_battery_info(sm->psy_bat, &sm->info))
		sm->info = NULL;

	sm->last_status = sm5714_get_status(sm);
	if (sm5714_get_capacity(sm, &sm->last_capacity))
		sm->last_capacity = -1;
	sm->last_online = sm5714_get_online(sm) > 0;

	INIT_DELAYED_WORK(&sm->poll_work, sm5714_poll_work);
	ret = devm_add_action_or_reset(dev, sm5714_cancel_poll, sm);
	if (ret)
		return ret;
	schedule_delayed_work(&sm->poll_work,
			      msecs_to_jiffies(SM5714_POLL_INTERVAL_MS));

	return 0;
}

static const struct of_device_id sm5714_of_match[] = {
	{ .compatible = "siliconmitus,sm5714" },
	{ }
};
MODULE_DEVICE_TABLE(of, sm5714_of_match);

static const struct i2c_device_id sm5714_i2c_id[] = {
	{ "sm5714" },
	{ }
};
MODULE_DEVICE_TABLE(i2c, sm5714_i2c_id);

static struct i2c_driver sm5714_driver = {
	.driver = {
		.name = "sm5714-battery",
		.of_match_table = sm5714_of_match,
	},
	.probe = sm5714_probe,
	.id_table = sm5714_i2c_id,
};
module_i2c_driver(sm5714_driver);

MODULE_DESCRIPTION("Silicon Mitus SM5714 charger and fuel gauge");
MODULE_LICENSE("GPL");
