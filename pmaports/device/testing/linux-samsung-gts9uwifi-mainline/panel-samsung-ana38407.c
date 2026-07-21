// SPDX-License-Identifier: GPL-2.0-only
/*
 * DRM panel driver for the Samsung AMSA46AS02 (Anapass ANA38407 DDIC) as fitted
 * to the Galaxy Tab S9 Ultra Wi-Fi (SM-X910, "gts9uwifi").
 *
 * 2960x1848 command-mode DSI panel, 4 lanes, DSC 1.1 (2 slices 1480x77, 8bpp).
 * The DCS init/exit sequences and timings were recovered from the Samsung
 * open-source drop (opensource.samsung.com, SM-X910_EUR_16) panel data file and
 * from the stock DTBO; see docs/panel-ana38407-bringup.md.  Samsung's
 * proprietary gamma/VRR/ACL/mdnie machinery is intentionally NOT ported: the
 * DPU switches refresh rate by mode-set, and brightness goes through the
 * standard DCS 0x51 path.
 */

#include <linux/backlight.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>

#include <drm/display/drm_dsc.h>
#include <drm/display/drm_dsc_helper.h>
#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

struct ana38407 {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	struct drm_dsc_config dsc;
	struct regulator_bulk_data *supplies;
	struct gpio_desc *reset_gpio;
};

/*
 * gts9u panel rails (from the stock DTS): vddio 1.8 V (l12b), vdd 1.2 V,
 * vci 3.0 V (l13b) and the AMOLED ELVDD "avdd" ~5.5 V behind a GPIO load switch.
 * All four must be up before the DDIC will light.
 */
static const struct regulator_bulk_data ana38407_supplies[] = {
	{ .supply = "vddio" },
	{ .supply = "vdd" },
	{ .supply = "vci" },
	{ .supply = "avdd" },
};

static inline struct ana38407 *to_ana38407(struct drm_panel *panel)
{
	return container_of(panel, struct ana38407, panel);
}

static void ana38407_reset(struct ana38407 *ctx)
{
	/* Samsung reset-sequence <0 10 1 1>: assert low, release high. */
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	usleep_range(5000, 6000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);
	usleep_range(10000, 11000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	usleep_range(10000, 11000);
}

/*
 * Power-on DCS sequence, transcribed from the panel PDF (macros expanded).
 * Level keys 0xF0/0xF1 0x5A 0x5A unlock; 0xA5 0xA5 relock.  The 0xC0/0xB0/0xC1
 * triples are indirect DDIC register accesses (Samsung "gpara").
 */
static int ana38407_on(struct ana38407 *ctx)
{
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	ctx->dsi->mode_flags |= MIPI_DSI_MODE_LPM;

	/* sleep out */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x11);
	mipi_dsi_msleep(&dsi_ctx, 120);

	/* VBP_SETTING_FOR_SDC_IP */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x0a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x09, 0xfd, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0xa5, 0xa5);

	/* DISPLAY_ON_DELAY_SETTING */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x23);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x01, 0x04, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0xa5, 0xa5);

	/* MX_IP_ENABLE */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x23);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x09, 0xb2, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0xa5, 0xa5);

	/* TCON_INTR_SETTING (TE active low) */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x02);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x14, 0x46, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x13);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x08, 0xcf, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc1, 0x05);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x09, 0xcd, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf1, 0xa5, 0xa5);

	/* TE_ON */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x35, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	/* TSP_SYNC_ON */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x0b, 0xb9);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb9, 0xcc);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x0e, 0xb9);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb9, 0x15);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x10, 0xb9);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb9, 0x88, 0x88, 0x88, 0x88);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	/*
	 * DSC compression on + Picture Parameter Set.  The DPU also programs the
	 * DSC encoder from drm_dsc_config; the panel wants its exact PPS
	 * (samsung,no_qcom_pps), so send it verbatim.
	 */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x07, 0x01);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x0a,
		0x11, 0x00, 0x00, 0x89, 0x30, 0x80, 0x07, 0x38, 0x0b, 0x90,
		0x00, 0x4d, 0x05, 0xc8, 0x05, 0xc8, 0x02, 0x00, 0x03, 0xe5,
		0x00, 0x20, 0x0b, 0x07, 0x00, 0x14, 0x00, 0x0c, 0x01, 0x44,
		0x00, 0x7a, 0x18, 0x00, 0x10, 0xd0, 0x03, 0x0c, 0x20, 0x00,
		0x06, 0x0b, 0x0b, 0x33, 0x0e, 0x1c, 0x2a, 0x38, 0x46, 0x54,
		0x62, 0x69, 0x70, 0x77, 0x79, 0x7b, 0x7d, 0x7e, 0x01, 0x02,
		0x01, 0x00, 0x09, 0x40, 0x09, 0xbe, 0x19, 0xfc, 0x19, 0xfa,
		0x19, 0xf8, 0x1a, 0x38, 0x1a, 0x78, 0x1a, 0xb6, 0x2a, 0xf6,
		0x2b, 0x34, 0x2b, 0x74, 0x3b, 0x74, 0x6b, 0xf4);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	/* SP_SETTING */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc3, 0x02);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	/* default brightness dimming control (normal mode) */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x53, 0x28);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	mipi_dsi_msleep(&dsi_ctx, 50);

	/* display on */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x29);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);

	return dsi_ctx.accum_err;
}

static int ana38407_off(struct ana38407 *ctx)
{
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x28);	/* display off */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x10);	/* sleep in */
	mipi_dsi_msleep(&dsi_ctx, 120);

	return dsi_ctx.accum_err;
}

static int ana38407_prepare(struct drm_panel *panel)
{
	struct ana38407 *ctx = to_ana38407(panel);
	int ret;

	ret = regulator_bulk_enable(ARRAY_SIZE(ana38407_supplies), ctx->supplies);
	if (ret)
		return ret;

	/* qcom,supply-post-on-sleep = 20 ms (vddio) */
	usleep_range(20000, 21000);

	ana38407_reset(ctx);

	ret = ana38407_on(ctx);
	if (ret) {
		gpiod_set_value_cansleep(ctx->reset_gpio, 0);
		regulator_bulk_disable(ARRAY_SIZE(ana38407_supplies), ctx->supplies);
		return ret;
	}

	return 0;
}

static int ana38407_unprepare(struct drm_panel *panel)
{
	struct ana38407 *ctx = to_ana38407(panel);

	ana38407_off(ctx);
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);
	regulator_bulk_disable(ARRAY_SIZE(ana38407_supplies), ctx->supplies);

	return 0;
}

/* All five timing modes from the stock DTBO, hactive/vactive 2960x1848. */
static const struct drm_display_mode ana38407_modes[] = {
	{	/* 120 Hz */
		.clock = (2960 + 16 + 36 + 30) * (1848 + 16 + 32 + 32) * 120 / 1000,
		.hdisplay = 2960, .hsync_start = 2960 + 16, .hsync_end = 2960 + 16 + 36,
		.htotal = 2960 + 16 + 36 + 30,
		.vdisplay = 1848, .vsync_start = 1848 + 16, .vsync_end = 1848 + 16 + 32,
		.vtotal = 1848 + 16 + 32 + 32,
	},
	{	/* 60 Hz */
		.clock = (2960 + 256 + 256 + 255) * (1848 + 127 + 256 + 137) * 60 / 1000,
		.hdisplay = 2960, .hsync_start = 2960 + 256, .hsync_end = 2960 + 256 + 256,
		.htotal = 2960 + 256 + 256 + 255,
		.vdisplay = 1848, .vsync_start = 1848 + 127, .vsync_end = 1848 + 127 + 256,
		.vtotal = 1848 + 127 + 256 + 137,
	},
	{	/* 30 Hz */
		.clock = (2960 + 512 + 208 + 256) * (1848 + 512 + 512 + 512) * 30 / 1000,
		.hdisplay = 2960, .hsync_start = 2960 + 512, .hsync_end = 2960 + 512 + 208,
		.htotal = 2960 + 512 + 208 + 256,
		.vdisplay = 1848, .vsync_start = 1848 + 512, .vsync_end = 1848 + 512 + 512,
		.vtotal = 1848 + 512 + 512 + 512,
	},
};

static int ana38407_get_modes(struct drm_panel *panel,
			      struct drm_connector *connector)
{
	struct drm_display_mode *mode;
	int i, count = 0;

	for (i = 0; i < ARRAY_SIZE(ana38407_modes); i++) {
		mode = drm_mode_duplicate(connector->dev, &ana38407_modes[i]);
		if (!mode)
			continue;
		mode->type = DRM_MODE_TYPE_DRIVER;
		if (i == 0)
			mode->type |= DRM_MODE_TYPE_PREFERRED;
		mode->width_mm = 313;
		mode->height_mm = 196;
		drm_mode_set_name(mode);
		drm_mode_probed_add(connector, mode);
		count++;
	}

	connector->display_info.width_mm = 313;
	connector->display_info.height_mm = 196;

	return count;
}

static const struct drm_panel_funcs ana38407_panel_funcs = {
	.prepare = ana38407_prepare,
	.unprepare = ana38407_unprepare,
	.get_modes = ana38407_get_modes,
};

static int ana38407_bl_update(struct backlight_device *bl)
{
	struct mipi_dsi_device *dsi = bl_get_data(bl);
	u16 brightness = backlight_get_brightness(bl);
	int ret;

	dsi->mode_flags &= ~MIPI_DSI_MODE_LPM;
	ret = mipi_dsi_dcs_set_display_brightness_large(dsi, brightness);
	dsi->mode_flags |= MIPI_DSI_MODE_LPM;

	return ret;
}

static const struct backlight_ops ana38407_bl_ops = {
	.update_status = ana38407_bl_update,
};

static struct backlight_device *ana38407_create_backlight(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	const struct backlight_properties props = {
		.type = BACKLIGHT_RAW,
		.brightness = 2047,
		.max_brightness = 4095,		/* 12-bit DCS 0x51 */
	};

	return devm_backlight_device_register(dev, dev_name(dev), dev, dsi,
					      &ana38407_bl_ops, &props);
}

static void ana38407_dsc_config(struct ana38407 *ctx)
{
	struct drm_dsc_config *dsc = &ctx->dsc;

	/* Values decoded from the panel's PPS (WT 0x0A ...). */
	dsc->dsc_version_major = 1;
	dsc->dsc_version_minor = 1;
	dsc->slice_height = 77;
	dsc->slice_width = 1480;
	dsc->slice_count = 2;
	dsc->bits_per_component = 8;
	dsc->bits_per_pixel = 8 << 4;	/* 8.0 bpp, .4 fixed point */
	dsc->block_pred_enable = true;
}

static int ana38407_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	struct ana38407 *ctx;
	int ret;

	ctx = devm_drm_panel_alloc(dev, struct ana38407, panel,
				   &ana38407_panel_funcs,
				   DRM_MODE_CONNECTOR_DSI);
	if (IS_ERR(ctx))
		return PTR_ERR(ctx);

	ret = devm_regulator_bulk_get_const(dev, ARRAY_SIZE(ana38407_supplies),
					    ana38407_supplies, &ctx->supplies);
	if (ret < 0)
		return dev_err_probe(dev, ret, "failed to get panel regulators\n");

	ctx->reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(ctx->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(ctx->reset_gpio),
				     "failed to get reset gpio\n");

	ctx->dsi = dsi;
	mipi_dsi_set_drvdata(dsi, ctx);

	dsi->lanes = 4;
	dsi->format = MIPI_DSI_FMT_RGB888;
	dsi->mode_flags = MIPI_DSI_MODE_LPM | MIPI_DSI_CLOCK_NON_CONTINUOUS;

	ctx->panel.prepare_prev_first = true;

	ctx->panel.backlight = ana38407_create_backlight(dsi);
	if (IS_ERR(ctx->panel.backlight))
		return dev_err_probe(dev, PTR_ERR(ctx->panel.backlight),
				     "failed to create backlight\n");

	drm_panel_add(&ctx->panel);

	ana38407_dsc_config(ctx);
	dsi->dsc = &ctx->dsc;

	ret = mipi_dsi_attach(dsi);
	if (ret < 0) {
		drm_panel_remove(&ctx->panel);
		return dev_err_probe(dev, ret, "failed to attach to DSI host\n");
	}

	return 0;
}

static void ana38407_remove(struct mipi_dsi_device *dsi)
{
	struct ana38407 *ctx = mipi_dsi_get_drvdata(dsi);
	int ret;

	ret = mipi_dsi_detach(dsi);
	if (ret < 0)
		dev_err(&dsi->dev, "failed to detach from DSI host: %d\n", ret);

	drm_panel_remove(&ctx->panel);
}

static const struct of_device_id ana38407_of_match[] = {
	{ .compatible = "samsung,ana38407-amsa46as02" },
	{ }
};
MODULE_DEVICE_TABLE(of, ana38407_of_match);

static struct mipi_dsi_driver ana38407_driver = {
	.probe = ana38407_probe,
	.remove = ana38407_remove,
	.driver = {
		.name = "panel-samsung-ana38407",
		.of_match_table = ana38407_of_match,
	},
};
module_mipi_dsi_driver(ana38407_driver);

MODULE_DESCRIPTION("Samsung ANA38407 AMSA46AS02 (gts9u) DSI panel driver");
MODULE_LICENSE("GPL");
