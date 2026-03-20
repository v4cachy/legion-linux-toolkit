<p align="center">
  <img src="logo.png" width="90" alt="Legion Linux Toolkit Logo"/>
</p>

<h1 align="center">Legion Linux Toolkit</h1>

<p align="center">
  <strong>A native Linux power management dashboard for Lenovo Legion laptops</strong><br/>
  Built for CachyOS · KDE Plasma 6 · Wayland
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-v0.6.1--BETA-red?style=flat-square"/>
  <img src="https://img.shields.io/badge/status-beta-orange?style=flat-square"/>
  <img src="https://img.shields.io/badge/platform-Linux-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/desktop-KDE%20Plasma%206-purple?style=flat-square"/>
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square"/>
</p>

---

## 🖥️ Hardware Target

| | |
|---|---|
| **Model** | Lenovo Legion 5 15ACH6H (2021) |
| **CPU** | AMD Ryzen 7 5800H |
| **GPU** | NVIDIA RTX 3060 (Laptop) + AMD iGPU |
| **OS** | CachyOS / Arch Linux |
| **Desktop** | KDE Plasma 6 — Wayland |

> Other Legion 5/7 models with `ideapad_acpi` should work with minor adjustments.

---

## ✨ Features

### 🏠 Home
- ⚡ Power Mode dropdown — Quiet / Balanced / Performance / Custom
- 🔋 Battery Mode — Normal / Conservation (~60%) / Rapid Charge
- 🎮 GPU Working Mode — Hybrid / NVIDIA / Integrated (via envycontrol)
- 🔄 G-Sync & Display Overdrive toggles
- 🔌 Always on USB & Fn Lock toggles
- 📊 Live CPU & GPU stats — utilization, clock, temperature, fan RPM, VRAM

### 🔋 Battery
- 📈 Live battery %, voltage, health, charge cycles
- ⚙️ Charging mode controls — Conservation, Rapid Charge, USB Charging

### ⚡ Performance
- 🎛️ CPU governor, AMD boost toggle, EPP selector
- 🌡️ Enhanced thermal mode, fan full speed toggle

### 🖥️ Display
- ☀️ Screen brightness slider (amdgpu sysfs)
- 📐 Resolution selector — change display resolution instantly
- 🔄 Refresh rate selector — change Hz independently
- ✨ Display Overdrive & G-Sync toggles

### ⌨️ Keyboard RGB
- 🌈 4-zone RGB via LegionAura — Static, Breath, Wave, Hue, Off
- 🎨 Per-zone colour pickers + hex input
- 💡 Quick presets — Legion Red, Ocean, Sunset, Aurora and more
- 🔆 Keyboard backlight brightness slider

### ⚙️ System
- 🔒 Fn Lock, Super Key, Touchpad, Camera toggles
- 🎨 Theme — Dark / Dark Dimmed / OLED Black

### 🚀 Overclock
- 🔛 Master OC enable/disable toggle
- 🔧 CPU max/min frequency + TDP (PL1/PL2) sliders
- 🎮 GPU core offset, memory offset, power limit, temp target

### 🌀 Fan
- 📡 Live animated fan icons — spin speed matches actual RPM
- 🌡️ Auto mode — firmware thermal curves
- 💨 Full Speed mode — locks both fans to 100%

### 🎯 Actions
- 🔁 Auto profile switching on AC connect / battery disconnect

### 🔔 System Tray
- 🔴 Legion Y-blade logo icon with profile colour dot
- ⚡ Quick profile switching without opening dashboard
- 🖱️ Left-click opens dashboard, middle-click cycles profiles

---

## 🎨 Power Profiles

| Profile | Label | Colour | TDP | Fan |
|---------|-------|--------|-----|-----|
| `low-power` | Quiet | 🔵 Blue | 15W | Silent |
| `balanced` | Balanced | ⚪ White | 35W | Auto |
| `balanced-performance` | Performance | 🔴 Red | 45W | Gaming |
| `performance` | Custom | 🩷 Pink | 54W | Max |

---

## 📦 Requirements

**Required — auto-installed by `install.sh`:**
- `python-pyqt6` — GUI framework
- `qt6-wayland` — Wayland support for KDE Plasma 6
- `libnotify` — desktop notifications
- `kscreen` — resolution & refresh rate control

**Optional — install from AUR for full features:**
```bash
yay -S lenovo-legion-linux-dkms legionaura envycontrol
```
| Package | Feature |
|---------|---------|
| `lenovo-legion-linux-dkms` | Fan RPM, hardware sysfs paths, thermalmode, overdrive |
| `legionaura` | Keyboard RGB colour control |
| `envycontrol` | GPU mode switching |

---

## 🚀 Install

```bash
git clone https://github.com/v4cachy/legion-linux-toolkit
cd legion-linux-toolkit
sudo bash install.sh
```

**Start the tray after install:**
```bash
/usr/lib/legion-toolkit/legion-tray.py &
```

---

## 🔄 Update

```bash
sudo bash update.sh
```

Pulls latest from GitHub, reinstalls all files, restarts the daemon and tray automatically.

---

## 🗑️ Uninstall

```bash
sudo bash uninstall.sh
```

Removes every file that `install.sh` placed on the system, including systemd service, udev rules, polkit policy and autostart entry.

---

## 🐛 Bug Fixes (v0.6.1)

- 🔧 Fixed VRR toggle snapping back after being enabled
- 🔧 Fixed Performance profile showing wrong colour (was pink, now red)
- 🔧 Fixed FanPage crash — methods accidentally deleted during refactor
- 🔧 Fixed tray icon showing letter circle instead of Legion logo
- 🔧 Fixed `QBrush` NameError in tray icon (function defined before imports)
- 🔧 Fixed GPU mode combo sending wrong profile on index mismatch
- 🔧 Fixed battery temperature always showing `—`
- 🔧 Fixed OC page crash — orphaned lines referencing undefined variables
- 🔧 Removed broken Manual PWM fan controls (not supported by driver)
- 🔧 Fixed dashboard not launching after FanPage rewrite

---

## ⚠️ Known Limitations

- **Manual fan PWM** — not available on this driver version, fan curves are firmware-managed per power profile
- **Instant Boot / Flip to Start** — BIOS-only features, not exposed by the Linux driver
- **Display brightness** — requires `amdgpu_bl0` backlight node (present in Hybrid mode)

---

## 📄 License

MIT — free to use, modify and distribute.

---

<p align="center">
  Made with ❤️ for Linux on Lenovo Legion
</p>
