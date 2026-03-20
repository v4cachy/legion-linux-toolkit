# Legion Linux Toolkit (BETA)

<p align="center">
  <img src="logo.png" width="80" alt="Legion Logo"/>
</p>

> **Beta v0.6.1** — A power management and hardware control dashboard for Lenovo Legion laptops on Linux.

---

## Hardware

- **Model:** Lenovo Legion 5 15ACH6H (2021)
- **CPU:** AMD Ryzen 7 5800H
- **GPU:** NVIDIA RTX 3060 (Laptop) + AMD iGPU (Hybrid)
- **OS:** CachyOS / Arch Linux — KDE Plasma 6, Wayland

---

## Requirements

**Required (auto-installed by install.sh):**
- `python-pyqt6` — GUI framework
- `qt6-wayland` — Wayland support for KDE Plasma 6
- `libnotify` — desktop notifications
- `kscreen` — resolution and refresh rate control via kscreen-doctor

**Optional (install from AUR for full features):**
- `lenovo-legion-linux-dkms` — fan RPM monitoring, hardware sysfs paths, thermalmode, overdrive, gsync
- `legionaura` — keyboard RGB colour control
- `envycontrol` — GPU mode switching (Hybrid / Discrete / Integrated)

```bash
yay -S lenovo-legion-linux-dkms legionaura envycontrol
```

---

## Install

```bash
git clone https://github.com/v4cachy/legion-linux-toolkit
cd legion-linux-toolkit
sudo bash install.sh
```

**After install, start the tray:**
```bash
/usr/lib/legion-toolkit/legion-tray.py &
```

**To update after changing files:**
```bash
sudo bash update.sh
```

**To remove everything:**
```bash
sudo bash uninstall.sh
```

---

## Features

**Home Page**
- Live CPU stats — utilization, clock, temperature, fan RPM
- Live GPU stats — utilization, clock, temperature, VRAM, power draw
- Power Mode dropdown — Quiet / Balanced / Performance / Custom (via Fn+Q or GUI)
- Battery Mode dropdown — Normal / Conservation (~60%) / Rapid Charge
- GPU Working Mode — Hybrid / NVIDIA / Integrated (via envycontrol)
- G-Sync toggle, Display Overdrive toggle
- Always on USB toggle, Fn Lock toggle

**Battery Page**
- Live battery percentage, health, voltage, charge cycles
- Power draw, manufacturer, model, technology
- Charging settings — Normal, Conservation, Rapid Charge, USB Charging, Power Charge Mode

**Performance Page**
- CPU governor, AMD boost toggle, EPP dropdown
- Fan full speed toggle, enhanced thermal mode toggle
- Live CPU frequency, temperature, governor status

**Display Page**
- Screen brightness slider (via amdgpu sysfs)
- Display Overdrive and G-Sync toggles
- Resolution selector — change display resolution
- Refresh Rate selector — change Hz independently from resolution

**Keyboard Page**
- LegionAura integration — 4-zone RGB colour control
- Effects: Static, Breath, Wave, Hue, Off
- Per-zone colour pickers with hex input
- Quick presets — Legion Red, Ocean, Sunset, Aurora and more
- Keyboard backlight brightness slider (Fn+Space equivalent)

**System Page**
- Fn Lock, Super Key, Touchpad, Camera toggles
- Theme selector — Dark / Dark Dimmed / OLED Black

**Overclock Page**
- Enable/Disable OC master toggle
- CPU max/min frequency sliders + TDP PL1/PL2 sliders
- GPU core offset, memory offset, power limit, temp target, fan override
- Live GPU stats in the OC panel

**Fan Page**
- Live CPU and GPU fan RPM with colour-coded speed indicator
- Auto mode — firmware manages fan curves
- Full Speed mode — locks both fans to 100%
- Note: Manual PWM not available on this driver version (firmware-managed only)

**Actions Page**
- Auto profile switching on AC connect / battery disconnect

**System Tray**
- Legion Y-blade logo icon with profile colour dot
- Quick profile switching from tray menu
- Battery %, all hardware toggles accessible from right-click menu
- Left-click opens dashboard, middle-click cycles profiles

---

## Power Profiles

| Profile | Label | LED Colour | TDP | Fan Curve |
|---------|-------|-----------|-----|-----------|
| `low-power` | Quiet | 🔵 Blue | 15W | Silent |
| `balanced` | Balanced | ⚪ White | 35W | Auto |
| `balanced-performance` | Performance | 🔴 Red | 45W | Gaming |
| `performance` | Custom | 🩷 Pink | 54W | Max |

---

## Bug Fixes (v0.6.0)

- Fixed VRR toggle snapping back to off after being enabled
- Fixed profile buttons showing wrong colours (Performance was pink, Custom was red)
- Fixed keyboard page crashing when lenovo_legion_laptop module not loaded
- Fixed FanPage methods being deleted causing dashboard to not launch
- Fixed tray icon showing letter circle instead of Legion logo
- Fixed GPU mode combo sending wrong profile on index mismatch
- Fixed battery temperature always showing `—` (now scans multiple hwmon sources)
- Fixed Normal Charging "Apply" button replaced with proper toggle switch
- Removed broken Manual PWM fan controls (PWM not available on this driver version)
- Fixed QBrush NameError in tray icon when function defined before imports

---

## Known Limitations

- Manual fan speed via PWM not available — the `lenovo_legion_laptop` driver for this model does not expose writable PWM files. Fan curves are managed by firmware per power profile.
- Instant Boot and Flip to Start not available via software — these are BIOS-only features not exposed by the Linux driver.
- Display brightness requires `amdgpu_bl0` backlight node — present when running on the AMD iGPU in Hybrid mode.

---

## License

MIT
