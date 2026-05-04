#!/usr/bin/env python3
"""
Legion Linux Toolkit — System Tray
Hardware: Lenovo Legion 5 15ACH6H | CachyOS / KDE Plasma 6 Wayland

Left-click   → open dashboard
Middle-click → cycle power profile
Right-click  → full menu
"""
import os, sys, subprocess, socket as _sock
from pathlib import Path

os.environ["QT_QPA_PLATFORM"]                 = "wayland"
os.environ["QT_WAYLAND_DISABLE_WINDOWDECORATION"] = "1"
os.environ.setdefault("WAYLAND_DISPLAY", "wayland-0")
if "XDG_RUNTIME_DIR" not in os.environ:
    os.environ["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"

# ── Legion logo icon ──────────────────────────────────────────────────────────
_LEGION_ICON_B64 = "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"





try:
    from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
    from PyQt6.QtGui import (QIcon, QPixmap, QColor, QPainter,
                              QBrush, QFont, QAction, QActionGroup)
    from PyQt6.QtCore import Qt, QTimer
except ImportError:
    sys.exit("PyQt6 not found — sudo pacman -S python-pyqt6")

# ── Paths ──────────────────────────────────────────────────────────────────────
DAEMON_SOCKET     = "/run/legion-toolkit.sock"
GUI_BIN           = Path("/usr/lib/legion-toolkit/legion-gui.py")
IDEAPAD_BASE      = Path("/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00")
_POWERMODE_MAP = {1: "quiet", 2: "balanced", 3: "performance", 255: "custom"}

def _find_legion_base() -> Path:
    for pattern in ["pci*/*/*/PNP0C09:*", "pci*/*/*/VPC2004:*"]:
        try:
            for p in Path("/sys/devices").glob(pattern):
                if (p / "hwmon").exists() or (p / "fan_fullspeed").exists():
                    return p
        except: pass
    return Path("/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00")

def _find_legion_powermode() -> Path:
    for pattern in ["pci*/*/*/PNP0C09:*", "pci*/*/*/VPC2004:*"]:
        try:
            for p in Path("/sys/devices").glob(pattern):
                f = p / "powermode"
                if f.exists(): return f
        except: pass
    for base in [Path("/sys/bus/platform/drivers/legion"),
                 Path("/sys/module/legion_laptop/drivers/platform:legion")]:
        if base.exists():
            try:
                for d in base.iterdir():
                    f = d / "powermode"
                    if f.exists(): return f
            except: pass
    return Path("/tmp/nonexistent_powermode")

LEGION_POWERMODE  = _find_legion_powermode()
LEGION_BASE       = _find_legion_base()

def _read_powermode() -> str:
    try:
        return _POWERMODE_MAP.get(int(LEGION_POWERMODE.read_text().strip()), "balanced")
    except:
        return "balanced"
AMD_BOOST         = Path("/sys/devices/system/cpu/cpufreq/boost")
BAT               = Path("/sys/class/power_supply/BAT0")

CONSERVATION_MODE = IDEAPAD_BASE / "conservation_mode"
CAMERA_POWER      = IDEAPAD_BASE / "camera_power"
FN_LOCK           = IDEAPAD_BASE / "fn_lock"
USB_CHARGING      = IDEAPAD_BASE / "usb_charging"
TOUCHPAD          = LEGION_BASE  / "touchpad"
RAPID_CHARGE      = LEGION_BASE  / "rapidcharge"
WINKEY            = LEGION_BASE  / "winkey"
OVERDRIVE         = LEGION_BASE  / "overdrive"
def _find_gsync_path() -> Path:
    for pattern in ["pci*/*/*/PNP0C09:*/gsync", "pci*/*/*/VPC2004:*/gsync"]:
        try:
            for p in Path("/sys/devices").glob(pattern):
                return p
        except: pass
    return Path("/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/gsync")

GSYNC             = _find_gsync_path()
NVIDIA_BACKLIGHT = Path("/sys/class/backlight/nvidia_wmi_ec_backlight/brightness")
POWER_CHARGE_MODE = LEGION_BASE  / "powerchargemode"
THERMAL_MODE      = LEGION_BASE  / "thermalmode"
FAN_FULLSPEED     = LEGION_BASE  / "fan_fullspeed"

def _make_legion_tray_icon(profile: str) -> QIcon:
    """Legion Y-blade logo with a profile-coloured dot in the corner."""
    import base64 as _b64
    size = 64
    px = QPixmap(size, size)
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    # Draw the logo
    logo_data = _b64.b64decode(_LEGION_ICON_B64)
    logo_pm = QPixmap()
    logo_pm.loadFromData(logo_data)
    logo_pm = logo_pm.scaled(size, size,
        Qt.AspectRatioMode.KeepAspectRatio,
        Qt.TransformationMode.SmoothTransformation)
    ox = (size - logo_pm.width()) // 2
    oy = (size - logo_pm.height()) // 2
    p.drawPixmap(ox, oy, logo_pm)
    # Small profile-colour dot bottom-right
    color = QColor(_color(profile))
    p.setBrush(QBrush(color))
    p.setPen(Qt.PenStyle.NoPen)
    dot = 14
    p.drawEllipse(size - dot - 1, size - dot - 1, dot, dot)
    p.end()
    return QIcon(px)


# ── Profile definitions (UI names — "low-power" never shown to user) ──────────
# Internal sysfs name → display info
_PROFILE_INFO = {
    "quiet": {
        "label":  "Quiet",
        "icon":   "🔵",
        "color":  "#4a9eff",
        "letter": "Q",
        "desc":   "15W · Silent",
    },
    "balanced": {
        "label":  "Balanced",
        "icon":   "⚪",
        "color":  "#e0e0e0",
        "letter": "B",
        "desc":   "35W · Everyday",
    },
    "performance": {
        "label":  "Performance",
        "icon":   "🔴",
        "color":  "#ff4757",
        "letter": "P",
        "desc":   "54W · Gaming",
    },
    "custom": {
        "label":  "Custom",
        "icon":   "🩷",
        "color":  "#ff69b4",
        "letter": "C",
        "desc":   "54W · Custom",
    },
}

def _get_profiles() -> list[str]:
    return ["quiet", "balanced", "performance", "custom"]

def _label(sysfs_name: str) -> str:
    return _PROFILE_INFO.get(sysfs_name, {}).get("label", sysfs_name.title())

def _color(sysfs_name: str) -> str:
    return _PROFILE_INFO.get(sysfs_name, {}).get("color", "#888888")

def _letter(sysfs_name: str) -> str:
    return _PROFILE_INFO.get(sysfs_name, {}).get("letter", sysfs_name[0].upper())

# ── sysfs helpers ─────────────────────────────────────────────────────────────
def rd(path: Path, default="0") -> str:
    try:
        return path.read_text().strip()
    except Exception:
        return default

def _send_socket(cmd: str) -> str:
    """Send a command to the daemon socket. Returns response or ''."""
    try:
        s = _sock.socket(_sock.AF_UNIX, _sock.SOCK_STREAM)
        s.settimeout(2.0)
        s.connect(DAEMON_SOCKET)
        s.send((cmd + "\n").encode())
        resp = s.recv(64).decode().strip()
        s.close()
        return resp
    except Exception:
        return ""

def _write(path: Path, value: str):
    """Write sysfs via daemon socket (root), fallback pkexec."""
    resp = _send_socket(f"write:{path}:{value}")
    if resp == "ok":
        return
    try:
        subprocess.Popen(
            ["pkexec", "sh", "-c", f"echo {value} > {path}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

def _apply_profile(sysfs_name: str):
    """Apply profile via daemon socket. Falls back to direct powermode write."""
    resp = _send_socket(f"set:{sysfs_name}")
    if resp == "ok":
        return
    # fallback — write powermode directly
    rev = {"quiet": 1, "balanced": 2, "performance": 3, "custom": 255}
    try:
        val = rev.get(sysfs_name, 2)
        LEGION_POWERMODE.write_text(f"{val}\n")
    except Exception:
        pass

def _get_battery_pct() -> int:
    try:
        n = int(rd(BAT / "energy_now"))
        f = int(rd(BAT / "energy_full", "1"))
        return min(100, int(n * 100 / f))
    except Exception:
        return -1

def _get_ac() -> bool:
    try:
        for p in Path("/sys/class/power_supply").iterdir():
            if "AC" in p.name or "ADP" in p.name:
                return (p / "online").read_text().strip() == "1"
    except Exception:
        pass
    return False

# ── Tray icon ─────────────────────────────────────────────────────────────────

# ── Main tray class ───────────────────────────────────────────────────────────
class LegionTray:
    def __init__(self, app: QApplication):
        self.app      = app
        self._profiles = _get_profiles()
        self._profile  = _read_powermode()

        self.tray = QSystemTrayIcon()
        self.tray.setIcon(_make_legion_tray_icon(self._profile))
        self.tray.activated.connect(self._on_click)

        self.menu = QMenu()
        self._build_menu()
        self.tray.setContextMenu(self.menu)
        self._update_tooltip()

        # Poll every 500ms to catch Fn+Q and external changes
        self._timer = QTimer()
        self._timer.timeout.connect(self._poll)
        self._timer.start(500)

        self.tray.show()

    # ── Menu ─────────────────────────────────────────────────────────────────
    def _build_menu(self):
        self.menu.clear()
        m = self.menu

        # Header
        h = QAction("⚡  Legion Toolkit", m); h.setEnabled(False)
        m.addAction(h)

        # Battery status
        pct = _get_battery_pct()
        ac  = _get_ac()
        bat_icon = "🔌" if ac else "🔋"
        bat_lbl  = f"{bat_icon}  Battery: {pct}%" if pct >= 0 else f"{bat_icon}  Battery"
        ba = QAction(bat_lbl, m); ba.setEnabled(False)
        m.addAction(ba)
        m.addSeparator()

        # ── Power profiles ────────────────────────────────────────────────
        prof_title = QAction("  Power Mode", m); prof_title.setEnabled(False)
        m.addAction(prof_title)

        self._profile_group   = QActionGroup(m)
        self._profile_actions = {}
        self._profile_group.setExclusive(True)

        for p in self._profiles:
            info   = _PROFILE_INFO.get(p, {})
            icon   = info.get("icon", "")
            label  = info.get("label", p.title())
            desc   = info.get("desc", "")
            a = QAction(f"  {icon}  {label}  —  {desc}", m)
            a.setCheckable(True)
            a.setChecked(p == self._profile)
            a.triggered.connect(lambda chk, prof=p: self._set_profile(prof))
            self._profile_group.addAction(a)
            m.addAction(a)
            self._profile_actions[p] = a

        m.addSeparator()

        # ── Battery section ───────────────────────────────────────────────
        bat_title = QAction("  Battery", m); bat_title.setEnabled(False)
        m.addAction(bat_title)

        cons_val  = rd(CONSERVATION_MODE)
        rapid_val = rd(RAPID_CHARGE)
        usb_val   = rd(USB_CHARGING)

        self._cons_action  = QAction(
            ("🔋  Conservation Mode  ●" if cons_val  == "1" else "🔋  Conservation Mode  ○"), m)
        self._rapid_action = QAction(
            ("⚡  Rapid Charge  ●"       if rapid_val == "1" else "🐢  Rapid Charge  ○"), m)
        self._usb_action   = QAction(
            ("🔌  USB Charge (off)  ●"  if usb_val   == "1" else "🔌  USB Charge (off)  ○"), m)

        self._cons_action.triggered.connect(self._toggle_conservation)
        self._rapid_action.triggered.connect(self._toggle_rapid)
        self._usb_action.triggered.connect(self._toggle_usb)
        m.addAction(self._cons_action)
        m.addAction(self._rapid_action)
        m.addAction(self._usb_action)
        m.addSeparator()

        # ── Display section ───────────────────────────────────────────────
        disp_title = QAction("  Display", m); disp_title.setEnabled(False)
        m.addAction(disp_title)

        od_val    = rd(OVERDRIVE)
        gsync_val = rd(GSYNC)
        self._od_action    = QAction(
            ("🖥️   Display Overdrive  ●" if od_val    == "1" else "🖥️   Display Overdrive  ○"), m)
        self._gsync_action = QAction(
            ("🔄  G-Sync  ●"            if gsync_val == "1" else "🔄  G-Sync  ○"), m)
        self._gsync_action.triggered.connect(self._toggle_gsync)
        m.addAction(self._od_action)
        m.addAction(self._gsync_action)

        # Brightness Backlight (nvidia_wmi_ec_backlight)
        if NVIDIA_BACKLIGHT.exists():
            bl_val = rd(NVIDIA_BACKLIGHT)
            self._bl_action = QAction(
                ("💡  Brightness Backlight  ●" if int(bl_val) > 0 else "💡  Brightness Backlight  ○"), m)
            self._bl_action.triggered.connect(self._toggle_backlight)
            m.addAction(self._bl_action)
            m.addSeparator()
        m.addSeparator()

        # ── System section ────────────────────────────────────────────────
        sys_title = QAction("  System", m); sys_title.setEnabled(False)
        m.addAction(sys_title)

        fn_val  = rd(FN_LOCK)
        cam_val = rd(CAMERA_POWER)
        tp_val  = rd(TOUCHPAD)
        wk_val  = rd(WINKEY)

        self._fn_action     = QAction(
            ("⌨️   Fn Lock  ●"   if fn_val  == "1" else "⌨️   Fn Lock  ○"), m)
        self._cam_action    = QAction(
            ("📷  Camera  ●"    if cam_val == "1" else "📷  Camera  ○"), m)
        self._tp_action     = QAction(
            ("🖱️   Touchpad  ●"  if tp_val  == "1" else "🖱️   Touchpad  ○"), m)
        self._winkey_action = QAction(
            ("🪟  Super Key  ●"  if wk_val  == "1" else "🪟  Super Key  ○"), m)

        self._fn_action.triggered.connect(self._toggle_fn)
        self._cam_action.triggered.connect(self._toggle_cam)
        self._tp_action.triggered.connect(self._toggle_tp)
        self._winkey_action.triggered.connect(self._toggle_winkey)
        m.addAction(self._fn_action)
        m.addAction(self._cam_action)
        m.addAction(self._tp_action)
        m.addAction(self._winkey_action)
        m.addSeparator()

        # ── Fan section ───────────────────────────────────────────────────
        fan_title = QAction("  Fan", m); fan_title.setEnabled(False)
        m.addAction(fan_title)

        fan_val = rd(FAN_FULLSPEED)
        tm_val  = rd(THERMAL_MODE)
        self._fan_action = QAction(
            ("🌀  Fan Full Speed  ●"  if fan_val == "1" else "🌀  Fan Full Speed  ○"), m)
        self._tm_action  = QAction(
            ("🌡️   Enhanced Thermal  ●" if tm_val  == "1" else "🌡️   Enhanced Thermal  ○"), m)
        self._fan_action.triggered.connect(self._toggle_fan)
        self._tm_action.triggered.connect(self._toggle_thermal)
        m.addAction(self._fan_action)
        m.addAction(self._tm_action)
        m.addSeparator()

        # ── Status line ───────────────────────────────────────────────────
        boost = rd(AMD_BOOST)
        s = QAction(f"  CPU Boost: {'ON' if boost == '1' else 'OFF'}", m)
        s.setEnabled(False)
        m.addAction(s)
        m.addSeparator()

        # ── Dashboard / Quit ──────────────────────────────────────────────
        dash = QAction("📊  Open Dashboard", m)
        dash.triggered.connect(self._open_dashboard)
        m.addAction(dash)
        m.addSeparator()

        quit_a = QAction("✕  Quit", m)
        quit_a.triggered.connect(self.app.quit)
        m.addAction(quit_a)

    def _update_tooltip(self):
        lbl = _label(self._profile)
        pct = _get_battery_pct()
        bat = f" · 🔋 {pct}%" if pct >= 0 else ""
        self.tray.setToolTip(f"Legion Toolkit — {lbl}{bat}")

    # ── Click handler ─────────────────────────────────────────────────────────
    def _on_click(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self._open_dashboard()
        elif reason == QSystemTrayIcon.ActivationReason.MiddleClick:
            self._cycle()

    def _open_dashboard(self):
        import subprocess as _sp
        # Kill any stale/crashed instance first
        try:
            _sp.run(["pkill", "-f", "legion-gui.py"],
                    stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
        except Exception:
            pass
        import time as _t; _t.sleep(0.15)   # brief pause so port/socket frees up
        try:
            _sp.Popen(
                ["python3", str(GUI_BIN)],
                stdout=open("/tmp/legion-gui.log","w"),
                stderr=open("/tmp/legion-gui.log","w")
            )
        except Exception as e:
            self.tray.showMessage("Legion Toolkit",
                                  f"Could not launch dashboard: {e}",
                                  QSystemTrayIcon.MessageIcon.Critical, 4000)

    def _cycle(self):
        profiles = self._profiles
        idx = profiles.index(self._profile) if self._profile in profiles else 0
        self._set_profile(profiles[(idx + 1) % len(profiles)])

    # ── Profile switch ────────────────────────────────────────────────────────
    def _set_profile(self, sysfs_name: str):
        _apply_profile(sysfs_name)
        self._update_ui(sysfs_name)
        lbl  = _label(sysfs_name)
        info = _PROFILE_INFO.get(sysfs_name, {})
        self.tray.showMessage(
            "Legion Toolkit",
            f"{info.get('icon','')} {lbl}  —  {info.get('desc','')}",
            QSystemTrayIcon.MessageIcon.Information, 2000
        )

    # ── Toggle helpers ────────────────────────────────────────────────────────
    def _tog(self, path: Path, action: QAction, on_lbl: str, off_lbl: str,
             notif_msg_on: str = "", notif_msg_off: str = ""):
        cur = rd(path)
        new = "0" if cur == "1" else "1"
        _write(path, new)
        action.setText(on_lbl if new == "1" else off_lbl)
        msg = notif_msg_on if new == "1" else notif_msg_off
        if msg:
            self.tray.showMessage("Legion Toolkit", msg,
                                  QSystemTrayIcon.MessageIcon.Information, 2000)

    def _toggle_conservation(self):
        self._tog(CONSERVATION_MODE, self._cons_action,
                  "🔋  Conservation Mode  ●", "🔋  Conservation Mode  ○",
                  "Conservation ON — charging capped at ~60%",
                  "Conservation OFF — normal charging")

    def _toggle_rapid(self):
        self._tog(RAPID_CHARGE, self._rapid_action,
                  "⚡  Rapid Charge  ●", "🐢  Rapid Charge  ○",
                  "Rapid charge ON", "Normal charging ON")

    def _toggle_usb(self):
        self._tog(USB_CHARGING, self._usb_action,
                  "🔌  USB Charge (off)  ●", "🔌  USB Charge (off)  ○")

    def _toggle_overdrive(self):
        self._tog(OVERDRIVE, self._od_action,
                  "🖥️   Display Overdrive  ●", "🖥️   Display Overdrive  ○",
                  "Display overdrive ON", "Display overdrive OFF")

    def _toggle_gsync(self):
        self._tog(GSYNC, self._gsync_action,
                  "🔄  G-Sync  ●", "🔄  G-Sync  ○",
                  "G-Sync ON", "G-Sync OFF")

    def _toggle_backlight(self):
        cur = int(rd(NVIDIA_BACKLIGHT, "0"))
        mx_path = Path("/sys/class/backlight/nvidia_wmi_ec_backlight/max_brightness")
        mx = int(rd(mx_path, "800"))
        new_val = "0" if cur > 0 else str(mx)
        _write(NVIDIA_BACKLIGHT, new_val)
        self._bl_action.setText(
            ("💡  Brightness Backlight  ●" if new_val != "0" else "💡  Brightness Backlight  ○"))

    def _toggle_fn(self):
        self._tog(FN_LOCK, self._fn_action,
                  "⌨️   Fn Lock  ●", "⌨️   Fn Lock  ○",
                  "Fn Lock ON", "Fn Lock OFF")

    def _toggle_cam(self):
        self._tog(CAMERA_POWER, self._cam_action,
                  "📷  Camera  ●", "📷  Camera  ○",
                  "Camera ON", "Camera OFF")

    def _toggle_tp(self):
        self._tog(TOUCHPAD, self._tp_action,
                  "🖱️   Touchpad  ●", "🖱️   Touchpad  ○",
                  "Touchpad enabled", "Touchpad disabled")

    def _toggle_winkey(self):
        self._tog(WINKEY, self._winkey_action,
                  "🪟  Super Key  ●", "🪟  Super Key  ○",
                  "Super key enabled", "Super key disabled")

    def _toggle_fan(self):
        self._tog(FAN_FULLSPEED, self._fan_action,
                  "🌀  Fan Full Speed  ●", "🌀  Fan Full Speed  ○",
                  "Fan → full speed", "Fan → auto")

    def _toggle_thermal(self):
        self._tog(THERMAL_MODE, self._tm_action,
                  "🌡️   Enhanced Thermal  ●", "🌡️   Enhanced Thermal  ○",
                  "Enhanced thermal ON", "Enhanced thermal OFF")

    # ── Update UI ─────────────────────────────────────────────────────────────
    def _update_ui(self, profile: str):
        self._profile = profile
        self.tray.setIcon(_make_legion_tray_icon(profile))
        self._update_tooltip()
        if profile in self._profile_actions:
            self._profile_actions[profile].setChecked(True)

    # ── Poll Fn+Q and battery ─────────────────────────────────────────────────
    def _poll(self):
        current = _read_powermode()
        if current != self._profile:
            self._update_ui(current)
            # Rebuild menu to refresh all toggle states
            self._build_menu()
            self.tray.setContextMenu(self.menu)
        else:
            # Update tooltip battery% quietly every poll
            self._update_tooltip()


# ── Entry point ────────────────────────────────────────────────────────────────
def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Legion Toolkit")
    app.setQuitOnLastWindowClosed(False)

    if not QSystemTrayIcon.isSystemTrayAvailable():
        sys.exit("No system tray available")

    LegionTray(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
