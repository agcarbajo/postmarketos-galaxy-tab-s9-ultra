# postmarketOS for the Samsung Galaxy Tab S9 Ultra Wi-Fi

A **mainline-first** postmarketOS port for the Samsung Galaxy Tab S9 Ultra Wi-Fi
(**SM-X910**, codename `gts9uwifi`, Qualcomm SM8550 "kalama"), running upstream
Linux **7.2-rc3**.

The goal is a real Linux desktop on the tablet — DRM/KMS, Mesa/Turnip, XFCE —
without depending on Samsung's downstream 5.15 kernel, which is used here only
as hardware documentation.

## Status

The tablet boots to a full **GNOME** desktop on Wayland at **2960×1848 @
120 Hz** with GPU acceleration, Wi-Fi, Bluetooth, audio, physical buttons and
battery reporting. XFCE on Xorg is also supported and was the original target.
Samsung's cold-boot hand-off leaves the panel unreachable, so the first DCS
read returns `00 00 00`. The device package now runs one automatic
platform-level suspend/resume before starting the display manager; the DDIC
then reads `80 00 04` and GNOME starts without requiring power-button presses.
The Qualcomm SSC sensor protection domain is now running as well:
accelerometer, gyroscope, magnetometer and compass are live, GNOME rotates the
desktop automatically, and the book-cover Hall switch reports `SW_LID`.
What is left is mostly accessories and the unfinished parts of the sensor
stack: ambient light, S Pen, cameras, the keyboard cover, external displays
and fast charging.

Mutter drives the split GPU/DPU topology by itself — it opens `card0` (Adreno)
as a GBM renderer and `card1` (DPU) for atomic mode setting — so none of the
reverse-PRIME plumbing that Xorg needs applies on Wayland. GNOME picks 200%
scaling on its own and looks right.

Everything marked ✅ has been **verified on the real hardware**, not inferred
from a driver binding. Audio, for instance, was only accepted after being
measured acoustically.

The system installs on microSD and boots from `boot`/`vendor_boot` on the
internal UFS. TWRP, Download Mode and Odin remain recoverable at all times.

## Hardware support

| Component | Status | Notes |
|---|---|---|
| **Display** | ✅ | ANA38407 / AMSA46AS02, 2960×1848 @ 120 Hz, DSI command mode + DSC + TE. Cold boot reads `00 00 00`; an automatic platform-level suspend test before GDM recovers it to `80 00 04`. Confirmed visually: the screen now turns on by itself |
| **Desktop** | ✅ | GNOME on Wayland (default) or XFCE on Xorg. GDM needs its greeter accounts pre-created — see below |
| **GPU** | ✅ | Adreno 740, Mesa/freedreno, OpenGL 4.6. Wayland uses both DRM devices directly; Xorg needs reverse PRIME (`card0` Adreno → `card1` DPU) |
| **Backlight and DPMS** | ✅ | Software brightness control and screen blanking |
| **Touchscreen** | ✅ | Goodix Berlin, 16-byte Samsung event layout |
| **Buttons** | ✅ | Volume up/down, and power (suspends) |
| **UFS storage** | ✅ | All six LUNs `sda`–`sdf` enumerate |
| **microSD** | ✅ | `mmcblk1`, holds the root filesystem |
| **Wi-Fi** | ✅ | WCN7850 / ath12k. Needs the PCIe PIPE mux unparked and the QRD board file |
| **Bluetooth** | ✅ | WCN7850, native address from EFS, persistent bonds, A2DP with real audio. HID untested |
| **Speakers** | ✅ | Four Cirrus CS35L45 over MI2S, confirmed acoustically |
| **Microphones** | ✅ | DMICs through the VA macro, capture measured at −30.6 dBFS |
| **System audio** | ✅ | Custom UCM profile → PulseAudio, all apps and desktop volume control |
| **Battery** | ✅ | Charge level, voltage, current and temperature via the Silicon Mitus SM5714 |
| **Charging status** | ✅ | Charging/discharging detected; UPower exposes both battery and line power |
| **Suspend** | 🟡 | Deep suspend/resume works. The cold-boot workaround uses the kernel's self-returning platform PM test, so it needs neither an RTC nor a power-button press. The SSC bridge and SensorProxy are restarted after resume |
| **USB** | 🟡 | Works as a secondary channel; Windows needs the composite driver forced (Code 43) |
| **Fast charging (45 W)** | ❌ | Capped at ~9 W. Needs the SM5714 USB-PD block (I²C `0x33`) and PD PPS negotiation |
| **USB-C video out** | ❌ | Upstream `sm8550.dtsi` already has the DisplayPort controller (`mdss_dp0`); what is missing is Type-C orientation and DP altmode — the same USB-PD gap as fast charging |
| **S Pen** | ❌ | Wacom `w90xx` digitizer at I²C `0x56`. Mainline ships a generic `wacom_i2c` driver that would need wiring up to this device |
| **Cover / lid detection** | 🟡 | The book-cover Hall switch on TLMM GPIO107 reports `SW_LID` and closing the cover suspends the tablet. The 30-second logind holdoff is disabled; reliable automatic wake on every opening still needs a final physical check |
| **Keyboard cover (pogo pins)** | ❌ | Bridged by an STM32 microcontroller (`stm,stm32_pogo`) at I²C `0x2a`, exposing keypad and touchpad. No mainline driver |
| **Fingerprint reader** | ❌ | EgisTec EL7xx (`etspi,el7xx`) over SPI. No mainline driver |
| **Camera flash / torch** | ❌ | `qcom,pm8350c-flash-led` on the PMIC. Mainline has `leds-qcom-flash` (`qcom,spmi-flash-led`) for this family |
| **Cameras** | ❌ | Not started |
| **Motion and orientation sensors** | ✅ | Qualcomm SSC on the ADSP exposes the LSM6DSO accelerometer/gyroscope and AK0991x magnetometer/compass. GNOME autorotation is physically verified with the X910 mount matrix |
| **Proximity sensor** | — | The stock X910 SSC configuration does not instantiate a proximity child; `ssccli` reports it unavailable |
| **Automatic brightness** | ❌ | The SSC discovers one Sensortek STK31610 ALS, but it emits no measurements. On-change, continuous/polling requests and the native Samsung registry were tested without a light sample |
| **Speaker protection** | ❌ | Cirrus DSP firmware is not loaded, which is why hardware volume is kept conservative |
| **Modem** | — | Not applicable: Wi-Fi-only model |

## Current focus

The next sensor milestone is to make the STK31610 ambient-light device produce
real lux samples. Its SSC service, SUID and attributes are present, but the DSP
accepts both on-change and continuous requests without sending a measurement.
The generated registry already matches Samsung's read-only `persist` registry,
so the remaining fault is below GNOME and iio-sensor-proxy. The cover-open
wake path also needs repeated physical validation at both the greeter and the
logged-in desktop.

## Documentation

> **Note:** the documents below are written in **Spanish**. This README is the
> only English-language document in the repository.

| Document | Contents |
|---|---|
| [docs/development-notes.md](docs/development-notes.md) | Goal, strategy, confirmed hardware facts, safety rules, and the inventory of what worked and what must not be retried |
| [docs/porting-log.md](docs/porting-log.md) | Chronological log, session by session |
| [docs/boot-strategy.md](docs/boot-strategy.md) | Boot chain, partitions, risks and recovery |
| [docs/upstream-audit.md](docs/upstream-audit.md) | What mainline supports and what has to be written |
| [docs/panel-ana38407-bringup.md](docs/panel-ana38407-bringup.md) | Panel bring-up |
| [docs/testing-mainline-v0.md](docs/testing-mainline-v0.md) | Manual test and rollback procedure |

## Layout

```text
├── pmaports/device/testing/   Alpine packages: kernel + DTS + patches,
│                              device package and firmware
├── scripts/                   reproducible build, packaging, firmware
│                              staging, audit and validation
├── configs/                   audio (UCM, udev), display, Bluetooth,
│                              Wi-Fi, vendor_boot, TWRP
└── docs/                      port documentation
```

## Installing

Two steps, always:

1. **Write the rootfs image to a microSD.** Wipe any previous partition table
   first (`sgdisk --zap-all`): a stale GPT backup header from a larger layout
   left at the end of the card makes different kernels disagree about where the
   partitions are, and the filesystems get read at the wrong offsets. Verify
   the write by hashing back what landed on the card before rebooting.
2. **Flash the TWRP ZIP.** It writes `boot`, `init_boot`, `vendor_boot` and
   `dtbo`, and applies the overlay onto the card — the GPU, ADSP and audio
   firmware live there, not in the device package, so a freshly written card
   has no working GPU until this step.

The root partition grows itself to fill whatever card it was written to on
first boot, so the image stays small and is not tied to one card size.

### GNOME and GDM

GDM 47+ runs its greeter as a per-display user `gdm-greeter-<N>` and asks
`systemd-userdbd` to allocate it on demand. **Alpine builds systemd without
userdbd**, so that path does not exist and GDM crash-loops on a black screen,
logging `User 'gdm-greeter-2' not preallocated and system lacks userdb`.

The device package works around it by pre-creating those accounts in the range
systemd itself reserves for dynamic users (61184–65519). Nothing to do by hand.

## Firmware

This repository contains **no proprietary firmware**. The Samsung and Qualcomm
blobs — Wi-Fi, Bluetooth, GPU, ADSP, CS35L45 and the audio topology — are
extracted from the device itself or from Samsung's open-source drop by the
`scripts/stage-stock-*.sh` helpers, which verify every file against pinned
checksums. Each SM-X910 owner regenerates their own.

## Licensing

This project is **MIT** (see [LICENSE](LICENSE)), except for the files derived
from Linux, which cannot be anything else. Every file declares its own terms
with an SPDX header, and that header **takes precedence** over this note:

| Part | Licence | Why |
|---|---|---|
| Kernel drivers (`sm5714_battery.c`, `panel-samsung-ana38407.c`) and patches | `GPL-2.0-only` | Derivative works of Linux; a requirement, not a choice |
| Device tree (`sm8550-samsung-gts9uwifi.dts`) | `BSD-3-Clause` | Matching the convention of Qualcomm's DTS files upstream |
| Packaging (`pmaports/`) | `MIT` | Same as pmaports upstream, so it can be sent there |
| Scripts, configuration and documentation | `MIT` | |
| Samsung/Qualcomm firmware | Proprietary | Not redistributed; staged from the device |

MIT as the default is deliberate rather than convenient: it is GPL-2.0
compatible, so work can flow both into the kernel and into pmaports (which is
itself MIT), whereas a GPL default could not go the other way. It is the choice
that gets in a contributor's way the least.

## Contributing

Contributions are welcome, especially on anything marked ❌ or 🟡. By
submitting a change you agree to publish it under whichever licence covers that
part of the tree, per the table above.

Two project habits worth keeping:

- **No live patching.** Every fix ends up in a DTS, config, APKBUILD or
  reproducible script, with `pkgrel` bumped and checksums updated.
- **Verify on the hardware.** A driver binding is not evidence that a subsystem
  works.
