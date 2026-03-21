<div align="center">
  <img src="logo.png" width="80" alt="Legion Linux Toolkit"/>
  <h1>Legion Linux Toolkit</h1>
  <p><strong>A native Linux power management dashboard for Lenovo laptops</strong></p>
  <p>Built for CachyOS · KDE Plasma 6 · Wayland</p>

  <p>
    <img src="https://img.shields.io/badge/version-v0.6.1--BETA-red?style=flat-square"/>
    <img src="https://img.shields.io/badge/build-20260320-orange?style=flat-square"/>
    <img src="https://img.shields.io/badge/platform-Linux-blue?style=flat-square"/>
    <img src="https://img.shields.io/badge/desktop-KDE%20Plasma%206-purple?style=flat-square"/>
    <img src="https://img.shields.io/badge/python-PyQt6-green?style=flat-square"/>
    <img src="https://img.shields.io/badge/license-MIT-white?style=flat-square"/>
  </p>
</div>

---

## 📸 Screenshots

<div align="center">

### 🏠 Home
![Home](screenshots/Home.png)

### 🔋 Battery &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ⚡ Performance
<p>
  <img src="screenshots/Battery.png" width="49%"/>
  <img src="screenshots/Perf.png" width="49%"/>
</p>

### 🖥️ Display &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ⌨️ Keyboard RGB
<p>
  <img src="screenshots/Display.png" width="49%"/>
  <img src="screenshots/Keyboard.png" width="49%"/>
</p>

### ⚙️ System &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 🌀 Fan
<p>
  <img src="screenshots/system.png" width="49%"/>
  <img src="screenshots/fan.png" width="49%"/>
</p>

### 🚀 Overclock &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 🎯 Actions
<p>
  <img src="screenshots/OC.png" width="49%"/>
  <img src="screenshots/Action.png" width="49%"/>
</p>

### ℹ️ About
![About](screenshots/about.png)

</div>

---

## 🖥️ Supported Hardware

| Brand | Models | Support |
|-------|--------|---------|
| 🎮 **Legion** | Legion 5, 5 Pro, 7, Slim 5/7 | ✅ Full — RGB, OC, GPU switching, fan, G-Sync |
| 🎮 **LOQ** | LOQ 15, 16 | ✅ Full — power, fan, GPU switching |
| 💼 **ThinkPad** | All modern ThinkPad models | ✅ Full + charge thresholds, fan levels 0–7, TrackPoint |
| 🔄 **Yoga** | Yoga 6, 7, 9, Slim series | ✅ Full + hinge mode, auto-rotate |
| 💻 **IdeaPad** | IdeaPad 5, Flex, Slim | ✅ Standard — power, battery, toggles |
| 📋 **ThinkBook** | ThinkBook 14, 16 | ✅ Standard — power, battery, fingerprint |

> **Primary target:** Lenovo Legion 5 15ACH6H (2021) — AMD Ryzen 7 5800H · NVIDIA RTX 3060 · CachyOS · KDE Plasma 6

---

## ✨ Features

<details>
<summary><b>🏠 Home Page</b></summary>

- ⚡ Power Mode dropdown — Quiet / Balanced / Performance / Custom (also Fn+Q)
- 🔋 Battery Mode — Normal / Conservation (~60%) / Rapid Charge
- 🎮 GPU Working Mode — Hybrid / NVIDIA / Integrated (via envycontrol)
- 🔄 G-Sync & Display Overdrive toggles
- 🔌 Always on USB & Fn Lock toggles
- 📊 Live CPU & GPU stats — utilization, clock, temp, fan RPM, VRAM

</details>

<details>
<summary><b>🔋 Battery Page</b></summary>

- 📈 Live battery %, voltage, health, charge cycles, power draw, temperature
- ⚙️ Conservation (~60%), Rapid Charge, USB Charging, Power Charge Mode
- 🔧 **ThinkPad only** — Start/Stop charge threshold (e.g. 40%–80%)

</details>

<details>
<summary><b>🖥️ Display Page</b></summary>

- ☀️ Screen brightness slider — auto-detects `nvidia_wmi_ec_backlight`, `amdgpu_bl0` etc.
- 📐 Resolution & Refresh Rate selectors (independent, via kscreen)
- ✨ Display Overdrive & G-Sync toggles

</details>

<details>
<summary><b>⌨️ Keyboard RGB (Legion)</b></summary>

- 🌈 4-zone RGB via LegionAura — Static, Breath, Wave, Hue, Off
- 🎨 Per-zone colour pickers + hex input
- 💡 Quick presets — Legion Red, Ocean, Sunset, Aurora
- 🔆 Keyboard backlight brightness slider

</details>

<details>
<summary><b>⚙️ System Page</b></summary>

- 🔒 Fn Lock, Super Key, Touchpad, Camera toggles
- 🎨 Theme — Dark / Dark Dimmed / OLED Black
- 🔴 **ThinkPad only** — TrackPoint sensitivity & speed sliders
- 💡 **ThinkPad only** — ThinkLight & Mic Mute LED toggles
- 🔄 **Yoga only** — Hinge mode display, orientation lock toggle

</details>

<details>
<summary><b>🌀 Fan Page</b></summary>

- 🎡 Animated fan icons — real-time spin driven by actual RPM
- 🌡️ Auto mode — firmware thermal curves
- 💨 Full Speed mode — locks both fans to 100%
- 🌀 **ThinkPad only** — Fan level dropdown (0–7, Auto, Disengaged)

</details>

<details>
<summary><b>🚀 Overclock Page</b></summary>

- 🔛 Master OC enable/disable toggle
- 🔧 CPU max/min frequency + TDP (PL1/PL2) sliders
- 🎮 GPU core offset, memory offset, power limit, temp target

</details>

---

## 🌍 Languages

First-run wizard — choose your language on first launch:

🇬🇧 English · 🇫🇷 Français · 🇩🇪 Deutsch · 🇪🇸 Español · 🇵🇹 Português · 🇹🇷 Türkçe · 🇷🇺 Русский · 🇨🇳 中文 · 🇯🇵 日本語 · 🇰🇷 한국어 · 🇸🇦 العربية

---

## 🎨 Power Profiles

| Profile | Label | LED | TDP |
|---------|-------|-----|-----|
| `low-power` | Quiet | 🔵 Blue | 15W |
| `balanced` | Balanced | ⚪ White | 35W |
| `balanced-performance` | Performance | 🔴 Red | 45W |
| `performance` | Custom | 🩷 Pink | 54W |

---

## 📦 Requirements

**Core — auto-installed:**
```
python-pyqt6   qt6-wayland   libnotify   kscreen   git
```

**Optional — auto-installed by brand:**

| Package | Manager | Brand | Feature |
|---------|---------|-------|---------|
| `lenovolegionlinux` + `lenovolegionlinux-dkms` | `pacman` | Legion / LOQ | Fan RPM, sysfs paths |
| `envycontrol` | `paru` | Legion / LOQ | GPU mode switching |
| `legionaura` | `yay` | Legion | Keyboard RGB |
| `fprintd` | `pacman` | ThinkPad / Yoga | Fingerprint |
| `iio-sensor-proxy` | `pacman` | Yoga | Auto-rotate |

---

## 🚀 Install

```bash
git clone https://github.com/v4cachy/legion-linux-toolkit
cd legion-linux-toolkit
sudo bash install.sh
```

> ✅ Auto-detects your Lenovo brand · installs brand-specific packages · hardware scan · launches tray automatically
> 
> 🧙 First launch shows the **setup wizard** — choose language and run one-time hardware detection

---

## 🔄 Update

```bash
sudo bash update.sh
```

Pulls latest from GitHub, shows commit log, reinstalls all files, restarts daemon and tray.

---

## 🗑️ Uninstall

```bash
sudo bash uninstall.sh
```

Removes everything — service, udev rules, polkit, autostart, CLI. Optionally removes user config.

---

## 🆕 What's New (v0.6.1 — 20260320)

- 🌍 11-language first-run wizard + one-time hardware detection
- 🏷️ Multi-brand: Legion, LOQ, ThinkPad, ThinkBook, Yoga, IdeaPad
- 🔧 ThinkPad — charge thresholds, fan levels 0–7, TrackPoint sliders, ThinkLight, Mic LED
- 🔄 Yoga — hinge mode display, orientation lock toggle
- 🎡 Animated fan icons driven by real RPM
- 🔴 Legion Y-blade logo in tray, sidebar and title bar
- 🎨 UI polish — cleaner topbar, brand-aware sidebar
- 📦 install.sh — brand detection, auto packages, wizard reset on reinstall
- 🔄 update.sh — `git reset --hard origin` (no more merge conflicts ever)

---

## ⚠️ Known Limitations

- Manual fan PWM — not available on Legion driver (firmware-managed)
- Instant Boot / Flip to Start — BIOS only
- Dolby Audio / Atmos — Windows driver only
- IR camera / Windows Hello — not supported

---

## 📄 License

MIT — free to use, modify and distribute.

---

<div align="center">
  <sub>Made with ❤️ for Linux on Lenovo · <a href="https://github.com/v4cachy/legion-linux-toolkit">github.com/v4cachy/legion-linux-toolkit</a></sub>
</div>
