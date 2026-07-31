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
Resume is stable with v1.08: it delays DCS `DISPLAY_ON` until the DRM enable
phase and replaces overlapping compositor wake timers with one cancellable
service. The cover now suspends and wakes the tablet reliably, including rapid
cycles, and the previously intermittent coloured DSC artefacts are gone.
Waking takes about 2–3 seconds because the platform must complete a deep
suspend/resume transaction before DRM and the Wayland session are ready.
The Qualcomm SSC sensor protection domain is now running as well:
accelerometer, gyroscope, magnetometer and compass are live, GNOME rotates the
desktop automatically, and the book-cover Hall switch reports `SW_LID`. v1.09
also serializes SSC recovery so rapid lid cycles cannot leave competing
FastRPC restarts behind.
What is left is mostly accessories and the unfinished parts of the sensor
stack: ambient light, S Pen, cameras, the keyboard cover and external displays.
v1.32 adds native USB-PD/PPS fast charging through the SM5714 and SM5440, with
the real battery thermistor used for safety. It also exposes the commercial
Snapdragon 8 Gen 2 and Adreno 740 names in Fastfetch and GNOME About. v1.14
also fixes two desktop-polish issues: a persisted
rotation lock no longer needs to be toggled after login, and the SM5714 driver
now restores the charging path that Samsung's shutdown sequence can leave
disabled.
v1.60 completes the physically validated USB host path with both powered and
bus-powered hubs. A powered
charge-through hub can keep supplying the tablet while the tablet acts as the
USB data host: TCPM negotiates 9 V / 1.66 A, xHCI enumerates a real Logitech
Lightspeed receiver, and the built-in Logitech DJ/HID++ drivers discover the
paired PRO X SUPERLIGHT 2 DEX with a working cursor, buttons and wheel. Three
powered disconnect/reconnect cycles and a later power-role transition all
enumerated it on the first attempt. The device
package also recreates xHCI after the platform suspend/resume used for cold-boot
panel recovery; it does so only if the tablet was already the host, so PC/RNDIS
device mode is left untouched. Mutter r6 keeps autorotation and its control
available when an external pointer is connected. The final clean v1.55 image
was tested again after restoring its matching signed ath12k modules: Wi-Fi
remained connected, the powered dock enumerated the receiver on its first
attempt in about 1.5 seconds, and GNOME simultaneously reported
`HasAccelerometer=true` and `PanelOrientationManaged=true`.

v1.60 validates generic unpowered host mode with a second, bus-powered hub.
The missing piece was the SM5714 MUIC's physical D-/D+ switch: Samsung's OTG
attach explicitly disables BC1.2 and selects its manual USB path. The mainline
driver now coordinates that route before exposing the host and also reports
its own OTG boost as valid VBUS to TCPM. The hub enumerates from a cold boot at
5.1 V / 900 mA together
with its Genesys USB2 controller, RTL8153 Ethernet and Logitech receiver; all
three reappear after the board-specific display recovery recreates xHCI.
PTN3222 changes from host/Connect Detect (`0e/01`) to an active USB link
(`0a/05`). The original charge-through dock still deliberately disables data
without its PD input (`USB_COMM=false`), which remains a limitation of that
dock rather than of the tablet. Device package r44 now pulls in
`linux-firmware-rtl_nic`; after a live driver rebind `ethtool -i` reports
`rtl8153a-3 v2 02/07/20`, although Ethernet traffic still needs a cable test.
A 16 GB USB 2.0 flash drive also enumerates through the passive hub, is
automounted as FAT32 and sustains a 128 MiB direct read at 20.4 MB/s without
errors. USB-C DisplayPort is now physically validated as well: the Type-C
altmode selects pin assignment D, HPD reaches the MSM DP bridge, the capture
sink exposes a 256-byte EDID and GNOME drives it at 1920x1080 @ 60 Hz. v1.64
also defers an already-attached dock's first HPD until after the board-specific
panel recovery, preventing the external encoder from resetting the tablet
during that platform suspend. v1.71 completes the retained-dock path: it gives
the powered partner a real CC detach, flushes the SM5714 RX buffer before
restarting its PD protocol layer, preserves the valid Sink/DFP pairing through
hard reset, and replays deferred HPD directly into MSM DP. Two consecutive
boots with the dock left physically connected restored the 9 V / 1.66 A
contract, Logitech mouse and 1920x1080 capture output without a replug. UAS
remains untested.

Mutter drives the split GPU/DPU topology by itself — it opens `card0` (Adreno)
as a GBM renderer and `card1` (DPU) for atomic mode setting — so none of the
reverse-PRIME plumbing that Xorg needs applies on Wayland. GNOME picks 200%
scaling on its own and looks right.

Everything marked ✅ has been **verified on the real hardware**, not inferred
from a driver binding. Audio, for instance, was only accepted after being
measured acoustically.

The system installs on microSD and boots from `boot`/`vendor_boot` on the
internal UFS. TWRP, Download Mode and Odin remain recoverable at all times.
Kernel lockdown is active, so `boot` and the two isolated ath12k modules are a
signed set. The ZIP installs them together; when iterating directly through
UFS, a kernel rebuilt from a clean output tree must never be written without
also updating its matching modules on the microSD.

## Hardware support

| Component | Status | Notes |
|---|---|---|
| **Display** | ✅ | ANA38407 / AMSA46AS02, 2960×1848 @ 120 Hz, DSI command mode + DSC + TE. Cold boot recovery is automatic. v1.08 fixes overlapping wake requests and implements the stock delayed `DISPLAY_ON`; repeated physical wake tests no longer show coloured DSC artefacts |
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
| **Charging status** | 🟡 | v1.14 classifies SDP/CDP/DCP through the SM5714 MUIC, restores Samsung's Q4 charging path and notifies UPower. v1.49 also negotiates a measured 9 V / 1.66 A PD contract through a powered hub. However, the user still observes intermittent charging indication and roughly five-hour estimates at low state of charge, both directly and through the hub; charging is therefore no longer considered fully polished |
| **Fast charging (45 W charger)** | 🟡 | v1.32 adds a mainline SM5714 Type-C/PD controller and a fail-safe SM5440 2:1 direct-charge driver. The official EP-T4510 entered PPS and real hardware previously measured about 2.8 A net into the battery at 78–82% state of charge. New low-state-of-charge testing reports slow and intermittent charging, so PPS/direct-charge stability must be revalidated after USB host work |
| **Suspend** | ✅ | Deep suspend/resume works. The cold-boot workaround uses the kernel's self-returning platform PM test, so it needs neither an RTC nor a power-button press. Display and SSC recovery use cancellable singleton services; the measured wake latency is about 2–3 seconds |
| **USB** | 🟡 | The RNDIS gadget works at High Speed when Windows is manually assigned the **Remote NDIS Compatible Device** driver. Powered host mode is validated at 9 V / 1.66 A with a Logitech Lightspeed receiver. v1.60 also validates a genuinely bus-powered hub at 5.1 V / 900 mA: the SM5714 MUIC routes D-/D+ before OTG VBUS, TCPM retains Source/Host, and Genesys `05e3:0610`, RTL8153 `0bda:8153` and Logitech `046d:c54d` enumerate from cold boot and after xHCI recovery. Built-in DJ/HID++ exposes the paired `046d:40b8` mouse; GNOME keeps autorotation managed. A USB 2.0 flash drive enumerates through the same passive hub, GNOME automounts its FAT32 partition, and a 128 MiB direct read completes at 20.4 MB/s without errors. Device r44 includes `linux-firmware-rtl_nic`; after installing it live and rebinding r8152, `ethtool -i` reports firmware `rtl8153a-3 v2 02/07/20`, but Ethernet traffic is still unverified because no cable was attached. The original charge-through dock still disables data when its own PD input is absent (`USB_COMM=false`). UAS remains untested because the available flash drive only advertises classic `usb-storage` |
| **USB-C video out** | ✅ | Physically validated through a USB-C dock and HDMI capture sink. The Type-C DP altmode selects pin D with HPD high; `card1-DP-1` reads the sink's 256-byte EDID and GNOME drives 1920×1080 @ 60 Hz while the internal DSI panel remains 2960×1848 @ 120 Hz. v1.61 advertises the local DP altmode, v1.63 associates the terminal MSM DP bridge with its firmware node so out-of-band HPD reaches DRM, and v1.64 defers HPD until after the X910 cold-boot panel recovery. v1.71 flushes retained SM5714 PD state and replays the saved HPD into MSM DP; two consecutive boots with the powered dock already attached restored PD, host USB, the mouse and external video without a replug |
| **S Pen** | ❌ | Wacom `w90xx` digitizer at I²C `0x56`. Mainline ships a generic `wacom_i2c` driver that would need wiring up to this device |
| **Cover / lid detection** | ✅ | The book-cover Hall switch on TLMM GPIO107 reports `SW_LID`; closing consistently suspends at the greeter and in-session, and opening wakes it again. v1.08 cancels stale compositor wakes between rapid cycles |
| **Keyboard cover (pogo pins)** | ❌ | Bridged by an STM32 microcontroller (`stm,stm32_pogo`) at I²C `0x2a`, exposing keypad and touchpad. No mainline driver |
| **Fingerprint reader** | ❌ | EgisTec EL7xx (`etspi,el7xx`) over SPI. No mainline driver |
| **Vibration motor / haptics** | ❌ | Hardware exists but has not been identified or brought up yet |
| **Camera flash / torch** | ❌ | `qcom,pm8350c-flash-led` on the PMIC. Mainline has `leds-qcom-flash` (`qcom,spmi-flash-led`) for this family |
| **Cameras** | ❌ | Not started |
| **Motion and orientation sensors** | ✅ | Qualcomm SSC on the ADSP exposes the LSM6DSO accelerometer/gyroscope and AK0991x magnetometer/compass. GNOME autorotation is physically verified with the X910 mount matrix; Mutter r5 keeps a persisted orientation lock independent from late panel/sensor inhibitors, and device-scoped Mutter r6 keeps panel orientation managed when a USB mouse is attached |
| **Proximity sensor** | — | The stock X910 SSC configuration does not instantiate a proximity child; `ssccli` reports it unavailable |
| **Automatic brightness** | ❌ | SSC discovers both Sensortek STK31610 instances, but neither emits a lux sample. Standard streaming modes, native registry data, Samsung's physical/DHR/register tests, sensor rails, QUP hub clocks and Samsung panel-state notifications have all been measured without success. The remaining boundary is inside the DSP's STK bus transaction, for which mainline currently exposes no diagnostic trace |
| **Speaker protection** | ❌ | Cirrus DSP firmware is not loaded, which is why hardware volume is kept conservative |
| **Modem** | — | Not applicable: Wi-Fi-only model |

## Current focus

DisplayPort cold-boot and hotplug robustness is complete in v1.71. The next
USB check is UAS with a capable SSD, followed by the remaining low-battery
charging instability.
USB gadget/RNDIS
works at High Speed when Windows uses the
RNDIS driver rather than an ADB driver. v1.33–v1.45 implemented the SM5714
DRP/OTG boost, stock CC/VCONN handling, QMP USB3/DP PHY, PS5169 retimer and
GPIO89 OTG-detect pulse. The powered-hub test exposed three final issues:
`HID_GENERIC` and the Logitech DJ/HID++ stack were still modules in a port
without a module tree; the initial
250 ms Type-C resync ran while TCPM was still in `PORT_RESET_WAIT_OFF`; and the
dock retained the unusual but valid Source/UFP pairing across a tablet reboot.
v1.46 makes generic HID built-in, v1.47 delays the one-shot resync to 1.5 s,
v1.48 lets the SM5714 opt into adopting DFP for that retained dock, and v1.50
makes the Logitech Lightspeed demultiplexer and HID++ driver built-in. v1.53
adds Samsung's in-place CC hold/toggle sequence for a Source-to-Sink PR_SWAP;
the powered dock can take over VBUS without electrically detaching its USB
data path.

On real hardware this produces a stable Sink/DFP Type-C partner, a 9 V /
1.66 A PD contract, both xHCI root hubs, and a Logitech receiver whose paired
PRO X SUPERLIGHT 2 DEX is exposed to GNOME with a complete relative-pointer
event node, and physical cursor movement is confirmed. The platform suspend
used to recover the panel then
triggered an xHCI Host System Error (`HS-PHY not in L2`). v1.49 adds a narrowly
scoped recovery: after that board-specific cycle, and after future real
resumes, it recreates xHCI only if the current USB role is already `host`.
Device/RNDIS mode is not changed.

Powered hotplug is now repeatable: three full detach/attach cycles all restored
the 9 V / 1.66 A contract and receiver on the first try. Removing and adding
the charger also preserves the tablet's DFP data role; adding power brings the
receiver back in about one second. The final clean v1.55 kernel and its matching
signed ath12k modules repeated that result: Wi-Fi stayed available, the receiver
was ready about 1.5 seconds after attach, and GNOME kept panel orientation
managed. The same dock cannot be used to prove
unpowered USB data, however: when bus-powered it explicitly advertises
`USB_COMM=false` and PTN3222 remains at `DEVICE_STATUS=0x0e`,
`LINK_STATUS=0x01` (host/Connect Detect, no downstream pull-up), even though
the X910 is correctly Source/Host at 5.1 V / 900 mA. An experimental TCPM
shortcut that completed Sink-to-Source PR_SWAP at VSAFE0V without the dock's
missing `PS_RDY` reduced the transition to 20 ms but did not change that
electrical result, so it was removed from the stable v1.55. The next checks
needed different hardware. v1.60 has now validated that second path with a
bus-powered Genesys/RTL8153 hub. The root cause was not TCPM role selection:
the SM5714 MUIC had left the connector D-/D+ pair physically disconnected.
Samsung's source-attach order is now reproduced:

1. begin the stock 130 ms GPIO89 OTG-detect pulse;
2. disable the MUIC BC1.2 engine and select the manual USB path;
3. enable the SM5714 5.1 V / 900 mA OTG boost and create xHCI.

The SM5714's `STATUS1.VBUS_POK` only reports incoming VBUS, so v1.59 also made
the TCPM transport treat the companion charger's active OTG boost as VBUS
present. Without that, TCPM dismantled an otherwise valid source attachment
after exactly 480 ms. v1.60 combines both fixes and enumerates the Genesys hub,
RTL8153 and Logitech receiver during cold boot and again after the expected
panel-recovery HSE. PTN3222 measures `DEVICE_STATUS=0x0a`,
`LINK_STATUS=0x05`, `HasAccelerometer=true` and
`PanelOrientationManaged=true` while the mouse is attached. Device r44 adds
`linux-firmware-rtl_nic`; installing it on the running tablet and rebinding
r8152 makes `ethtool -i` report `rtl8153a-3 v2 02/07/20`. `eth0` remains
`NO-CARRIER`, as expected with no Ethernet cable, so link and traffic are not
yet claimed. Classic USB mass storage is now validated with a FAT32 flash
drive and a 128 MiB direct read at 20.4 MB/s. DisplayPort and retained-dock
cold boot are now validated too; the next USB check is UAS with a capable SSD.

GNOME's former rotation regression was independent from USB. Its fallback
touch-mode heuristic stopped managing panel orientation whenever any pointer
appeared. The X910-specific Mutter r6 treats this fixed slate as orientation
managed whenever its accelerometer and built-in panel exist. With the Logitech
mouse attached, both `HasAccelerometer` and `PanelOrientationManaged` remain
true and the rotation control stays available.

Automatic brightness is deliberately parked rather than declared solved. SSC
publishes both native STK31610 SUIDs and accepts Samsung's factory requests,
but returns zero-filled DHR/register blocks and never emits lux. Rail, pinctrl,
registry, polling/DRI, QUP-clock and panel-notification experiments were all
measured and rolled back. Neither the Galaxy A52/A72 note nor Xiaomi Pad 6
contains a compatible STK31610 implementation to transplant.

Charging and USB data now share the same real TCPM/Type-C state rather than a
fixed peripheral-only path. The powered hub proves that charging and host data
can coexist, but it does not prove that low-battery fast charging is healthy:
the user still sees intermittent charging state and slow estimates even with
the official 45 W charger connected directly. That is the next independent
power task after host peripherals; it must not be hidden by the successful
9 V hub contract.

v1.14 closes the earlier polish work. Mutter keeps the persisted user rotation
lock separate from the anonymous panel-management inhibitor count, so a late
accelerometer can no longer consume the lock while the UI still says it is
enabled. The SM5714 driver now reads cable type from its MUIC, restores Q4 and
the known stock current limits, polls once per second for prompt UPower updates
and cancels I2C polling across suspend.

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
