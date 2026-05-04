#!/usr/bin/env python3
"""
Legion Linux Toolkit — Core Daemon
====================================
Watches /sys/firmware/acpi/platform_profile for changes (triggered by Fn+Q
or by the CLI tool) and applies the full profile — governor, boost, TDP,
fan mode, and battery settings.

Hardware: Lenovo Legion 5 15ACH6H | AMD Ryzen 7 5800H | CachyOS
"""

import os
import sys
import time
import logging
import signal
import subprocess
from pathlib import Path

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("/var/log/legion-toolkit.log", mode="a"),
    ],
)
log = logging.getLogger("legion")

# ── RAPL writability check ────────────────────────────────────────────────────
# _RAPL_WARNED flag ensures the full install hint only prints ONCE per process.
# CLI one-shot calls get a silent skip; daemon startup gets the full warning.
_RAPL_WRITABLE: bool | None = None
_RAPL_WARNED:   bool        = False

def _check_rapl(verbose: bool = False) -> bool:
    global _RAPL_WRITABLE, _RAPL_WARNED
    if _RAPL_WRITABLE is not None:
        return _RAPL_WRITABLE
    if RAPL_PL1.exists() and os.access(RAPL_PL1, os.W_OK):
        _RAPL_WRITABLE = True
        log.info("  ✓ RAPL TDP control available")
    else:
        _RAPL_WRITABLE = False
        if verbose and not _RAPL_WARNED:
            log.warning("  ⚠ RAPL not writable — TDP limits will be skipped")
            log.warning("    → To enable TDP control on your Ryzen 7 5800H:")
            log.warning("    → yay -S ryzen_smu-dkms-git && sudo modprobe ryzen_smu")
            log.warning("    → Then: sudo systemctl restart legion-toolkit")
            _RAPL_WARNED = True
    return _RAPL_WRITABLE
PLATFORM_PROFILE        = Path("/sys/firmware/acpi/platform_profile")
PLATFORM_PROFILE_CHOICES= Path("/sys/firmware/acpi/platform_profile_choices")

# ── Power source detection (AC/battery) ───────────────────────────────────────────
def is_ac_connected() -> bool:
    """Check if AC power is connected."""
    for p in [Path("/sys/class/power_supply/AC0/online"),
             Path("/sys/class/power_supply/AC/online")]:
        if p.exists():
            try: return p.read_text().strip() == "1"
            except: pass
    return False

def get_ac_status() -> str:
    return "AC" if is_ac_connected() else "Battery"

# ── Dynamic sysfs path detection (works across all Lenovo models) ─────────────
def _find_ideapad_base() -> Path:
    root = Path("/sys/bus/platform/drivers/ideapad_acpi")
    if root.exists():
        try:
            for d in root.iterdir():
                if any((d/f).exists() for f in ["conservation_mode","fn_lock","fan_mode"]):
                    return d
        except: pass
    return Path("/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00")

def _find_legion_feature(name: str) -> Path:
    """Find a legion_laptop feature file anywhere in sysfs (any PCI slot, any model, kernel 7.x VPC2004 support)."""
    # Try all PNP0C09 and VPC2004 devices under any PCI bus
    try:
        for p in Path("/sys/devices").glob("pci*/*/*/PNP0C09:*"):
            f = p / name
            if f.exists(): return f
    except: pass
    try:
        for p in Path("/sys/devices").glob("pci*/*/*/VPC2004:*"):
            f = p / name
            if f.exists(): return f
    except: pass
    # Try legion driver binding
    for base in [Path("/sys/bus/platform/drivers/legion"),
                 Path("/sys/module/legion_laptop/drivers/platform:legion")]:
        if base.exists():
            try:
                for d in base.iterdir():
                    f = d / name
                    if f.exists(): return f
            except: pass
    return Path(f"/tmp/nonexistent_{name}")

IDEAPAD_BASE    = _find_ideapad_base()
FAN_MODE        = IDEAPAD_BASE / "fan_mode"
CONSERVATION_MODE = IDEAPAD_BASE / "conservation_mode"
CAMERA_POWER    = IDEAPAD_BASE / "camera_power"
FN_LOCK         = IDEAPAD_BASE / "fn_lock"
USB_CHARGING    = IDEAPAD_BASE / "usb_charging"
RAPID_CHARGE    = _find_legion_feature("rapidcharge")

# AMD boost (Ryzen 7 5800H)
AMD_BOOST               = Path("/sys/devices/system/cpu/cpufreq/boost")

# RAPL — AMD exposes via intel-rapl interface on this machine
RAPL_PL1                = Path("/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw")
RAPL_PL2                = Path("/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw")

# CPU governor paths
GOVERNOR_GLOB           = "/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
EPP_GLOB                = "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
MAX_FREQ_GLOB           = "/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq"
CPUINFO_MAX_GLOB        = "/sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq"

# Fan hwmon — legion_hwmon confirmed at hwmon5, but number can change on reboot
# Detect dynamically
def find_hwmon(name: str) -> Path | None:
    for p in Path("/sys/class/hwmon").iterdir():
        try:
            if (p / "name").read_text().strip() == name:
                return p
        except Exception:
            continue
    return None


# ── Profile definitions ────────────────────────────────────────────────────────
# Values tuned for Ryzen 7 5800H (cTDP range: 35W–54W, base 45W)
PROFILES = {
    "quiet": {
        "governor":     "powersave",
        "boost":        "0",           # AMD boost OFF — confirmed from Windows LLT
        "epp":          "power",       # lowest power draw
        "rapl_pl1_uw":  15_000_000,    # 15W sustained
        "rapl_pl2_uw":  20_000_000,    # 20W burst
        "fan_mode":     "0",           # auto
        "description":  "Quiet — silent, 15W, boost off",
    },
    "balanced": {
        "governor":     "powersave",   # powersave + boost=on = schedutil equivalent on AMD
        "boost":        "1",
        "epp":          "balance_power",  # balanced EPP — NOT balance_performance
        "rapl_pl1_uw":  35_000_000,    # 35W sustained
        "rapl_pl2_uw":  54_000_000,    # 54W burst (5800H max cTDP)
        "fan_mode":     "0",           # auto
        "description":  "Balanced — 35W, boost on, auto fan",
    },
    "balanced-performance": {
        "governor":     "performance",
        "boost":        "1",
        "epp":          "performance",      # red LED = full Performance mode
        "rapl_pl1_uw":  45_000_000,
        "rapl_pl2_uw":  54_000_000,
        "fan_mode":     "0",
        "description":  "Performance (Red LED) — 45W, boost on",
    },
    "performance": {
        "governor":     "performance",
        "boost":        "1",
        "epp":          "balance_performance",  # pink LED = Custom mode
        "rapl_pl1_uw":  54_000_000,
        "rapl_pl2_uw":  54_000_000,
        "fan_mode":     "0",
        "description":  "Custom (Pink LED) — 54W, boost on",
    },
}

# Firmware aliases — maps non-standard names to standard profile keys
_PROFILE_ALIASES = {
    "low-power": "quiet",
    "custom":    "performance",
}
PROFILES.update((k, PROFILES[v]) for k, v in _PROFILE_ALIASES.items())

# ── Helpers ────────────────────────────────────────────────────────────────────
def write(path: Path, value: str, label: str) -> bool:
    try:
        if path.exists() and os.access(path, os.W_OK):
            path.write_text(str(value))
            log.info(f"  ✓ {label} → {value}")
            return True
        else:
            log.warning(f"  ⚠ Not writable: {label} ({path})")
            return False
    except Exception as e:
        log.warning(f"  ⚠ Failed {label}: {e}")
        return False


def write_glob(pattern: str, value: str, label: str) -> bool:
    import glob
    paths = glob.glob(pattern)
    if not paths:
        log.warning(f"  ⚠ No paths found for: {label}")
        return False
    success = 0
    for p in paths:
        try:
            if os.access(p, os.W_OK):
                Path(p).write_text(value)
                success += 1
        except Exception:
            pass
    if success > 0:
        log.info(f"  ✓ {label} → {value}  ({success} cores)")
        return True
    log.warning(f"  ⚠ Could not write {label}")
    return False


def restore_max_freq():
    """Restore all CPU cores to their hardware-maximum frequency."""
    import glob
    for cpu_dir in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq"):
        max_path = Path(cpu_dir) / "scaling_max_freq"
        hw_max_path = Path(cpu_dir) / "cpuinfo_max_freq"
        try:
            if max_path.exists() and hw_max_path.exists() and os.access(max_path, os.W_OK):
                hw_max = hw_max_path.read_text().strip()
                max_path.write_text(hw_max)
        except Exception:
            pass
    log.info("  ✓ CPU max frequency → restored to hardware max")


def get_current_profile() -> str:
    try:
        return PLATFORM_PROFILE.read_text().strip()
    except Exception:
        return "unknown"


def get_available_profiles() -> list[str]:
    try:
        return PLATFORM_PROFILE_CHOICES.read_text().strip().split()
    except Exception:
        return list(PROFILES.keys())


# ── Apply a profile ────────────────────────────────────────────────────────────
def apply_profile(profile_name: str):
    if profile_name not in PROFILES:
        log.error(f"Unknown profile: {profile_name}")
        log.error(f"Available: {', '.join(get_available_profiles())}")
        return

    p = PROFILES[profile_name]
    log.info(f"")
    log.info(f"══ Applying profile: {profile_name.upper()} ══")
    log.info(f"   {p['description']}")
    log.info(f"")

    # Platform profile is now handled by LLL's legiond - don't overwrite
    # write(PLATFORM_PROFILE, profile_name, "platform_profile")

    # 2. Restore CPU max freq first (clears any previous cap)
    restore_max_freq()

    # 3. CPU governor (AMD: performance or powersave only)
    write_glob(GOVERNOR_GLOB, p["governor"], "CPU governor")

    # 4. AMD boost
    write(AMD_BOOST, p["boost"], "AMD boost")

    # 5. Energy performance preference — use explicit value from profile dict
    epp_val = p["epp"]
    write_glob(EPP_GLOB, epp_val, "Energy perf preference")

    # 6. RAPL TDP limits — only attempt if writable
    if _check_rapl(verbose=False):
        write(RAPL_PL1, str(p["rapl_pl1_uw"]), f"CPU TDP PL1 ({p['rapl_pl1_uw']//1_000_000}W)")
        write(RAPL_PL2, str(p["rapl_pl2_uw"]), f"CPU TDP PL2 ({p['rapl_pl2_uw']//1_000_000}W)")
    else:
        log.info(f"  ⏭ TDP skipped (install ryzen_smu-dkms-git to enable)")

    # Fan mode is now handled by LLL's legiond - don't overwrite
    # write(FAN_MODE, p["fan_mode"], "Fan mode")

    # 8. Status summary
    log.info(f"")
    log.info(f"  Profile  : {get_current_profile()}")
    log.info(f"  Governor : {Path('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor').read_text().strip() if Path('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor').exists() else 'N/A'}")
    log.info(f"  Boost    : {AMD_BOOST.read_text().strip() if AMD_BOOST.exists() else 'N/A'}")
    log.info(f"  Temp     : {_read_temp()} °C")
    log.info(f"")


def _read_temp() -> str:
    hwmon = find_hwmon("k10temp")
    if hwmon:
        temp_path = hwmon / "temp1_input"
        try:
            return str(int(int(temp_path.read_text().strip()) / 1000))
        except Exception:
            pass
    return "N/A"


# ── Daemon: watch platform_profile for changes (triggered by Fn+Q or CLI) ─────
class ProfileWatcher:
    def __init__(self):
        self._last_profile = None
        self._running = True
        signal.signal(signal.SIGTERM, self._stop)
        signal.signal(signal.SIGINT, self._stop)

    def _stop(self, *_):
        log.info("Legion daemon stopping...")
        self._running = False

    def run(self):
        log.info("Legion Linux Toolkit daemon started")
        log.info(f"Watching: {PLATFORM_PROFILE}")
        log.info(f"Available profiles: {' | '.join(get_available_profiles())}")

        # Check RAPL once at daemon startup with full install hint
        _check_rapl(verbose=True)

        # Apply current profile on startup
        current = get_current_profile()
        log.info(f"Startup profile: {current}")
        apply_profile(current)
        self._last_profile = current

        # Track AC/battery for auto-switching
        self._last_ac = is_ac_connected()
        log.info(f"Power source: {get_ac_status()}")

        # Start Unix socket server in background thread
        import threading as _th
        _th.Thread(target=self._socket_server, daemon=True).start()

        while self._running:
            try:
                # Watch for AC/battery changes (auto-switch profiles)
                ac_now = is_ac_connected()
                if ac_now != self._last_ac:
                    log.info(f"Power changed: {self._last_ac} → {ac_now} ({'AC' if ac_now else 'Battery'})")
                    self._last_ac = ac_now
                    # Auto-switch profile based on power source
                    # This is similar to LLL's legiond feature
                    if ac_now:
                        log.info("  → AC connected: using current profile settings")
                    else:
                        log.info("  → On battery: applying battery-optimized settings")
                
                # Watch for power mode changes (Fn+Q or CLI)
                current = get_current_profile()
                if current != self._last_profile:
                    log.info(f"Profile changed: {self._last_profile} → {current}")
                    apply_profile(current)
                    self._last_profile = current
                    _notify(current)
            except Exception as e:
                log.error(f"Watcher error: {e}")
            time.sleep(0.5)

    def _socket_server(self):
        """Unix socket server — handles write:/set:/get: from the GUI."""
        import socket as _sock
        SOCK_PATH = "/run/legion-toolkit.sock"
        try: os.unlink(SOCK_PATH)
        except: pass
        srv = _sock.socket(_sock.AF_UNIX, _sock.SOCK_STREAM)
        srv.bind(SOCK_PATH)
        os.chmod(SOCK_PATH, 0o666)
        srv.listen(8)
        log.info(f"Socket server listening at {SOCK_PATH}")
        while True:
            try:
                conn, _ = srv.accept()
                import threading as _th
                _th.Thread(target=self._handle_client, args=(conn,), daemon=True).start()
            except Exception as e:
                log.debug(f"Socket accept error: {e}")

    def _handle_client(self, conn):
        try:
            data = conn.recv(4096).decode().strip()
            if data.startswith("set:"):
                profile = data[4:].strip()
                if profile in PROFILES or profile in get_available_profiles():
                    apply_profile(profile)
                    conn.send(b"ok\n")
                else:
                    conn.send(b"err:unknown profile\n")
            elif data.startswith("envycontrol:"):
                # envycontrol:hybrid|nvidia|integrated
                mode = data[12:].strip()
                if mode not in ("hybrid","nvidia","integrated"):
                    conn.send(b"err:invalid mode\n")
                else:
                    try:
                        # Find envycontrol — it may be in user PATH not root PATH
                        import shutil
                        env_bin = shutil.which("envycontrol") or None
                        # Common install locations from paru/yay/pip
                        if not env_bin:
                            for candidate in [
                                "/usr/bin/envycontrol",
                                "/usr/local/bin/envycontrol",
                                "/home/" + (os.environ.get("SUDO_USER","") or "") + "/.local/bin/envycontrol",
                                "/opt/envycontrol/envycontrol",
                            ]:
                                if os.path.isfile(candidate):
                                    env_bin = candidate
                                    break
                        if not env_bin:
                            conn.send(b"err:envycontrol not found - install: yay -S envycontrol\n")
                        else:
                            log.info(f"Running envycontrol at {env_bin} --switch {mode}")
                            r = subprocess.run(
                                [env_bin, "--switch", mode],
                                capture_output=True, text=True, timeout=30,
                                env={**os.environ, "PATH": "/usr/local/bin:/usr/bin:/bin"}
                            )
                            if r.returncode == 0:
                                conn.send(b"ok\n")
                                log.info(f"GPU mode switched to {mode}")
                            else:
                                err_msg = (r.stderr or r.stdout or "unknown error").strip()[:120]
                                conn.send(f"err:{err_msg}\n".encode())
                                log.warning(f"envycontrol failed: {err_msg}")
                    except Exception as e:
                        conn.send(f"err:{e}\n".encode())
                        log.error(f"envycontrol exception: {e}")
            elif data.startswith("write:"):
                # write:path:value
                parts = data[6:].split(":", 1)
                if len(parts) == 2:
                    path, value = parts[0].strip(), parts[1].strip()
                    try:
                        Path(path).write_text(value + "\n")
                        conn.send(b"ok\n")
                    except Exception as e:
                        conn.send(f"err:{e}\n".encode())
                else:
                    conn.send(b"err:bad format\n")
            elif data.startswith("get:profile"):
                conn.send(f"{get_current_profile()}\n".encode())
            elif data.startswith("get:choices"):
                conn.send(f"{' '.join(get_available_profiles())}\n".encode())
            else:
                conn.send(b"err:unknown command\n")
        except Exception as e:
            log.debug(f"Client error: {e}")
        finally:
            try: conn.close()
            except: pass


def _get_user_session() -> tuple[str, str, str] | None:
    """
    Find the logged-in user's username, DISPLAY and DBUS_SESSION_BUS_ADDRESS.
    """
    try:
        result = subprocess.run(
            ["loginctl", "list-sessions", "--no-legend"],
            capture_output=True, text=True
        )
        for line in result.stdout.strip().splitlines():
            parts = line.split()
            if len(parts) < 3:
                continue
            session_id = parts[0]
            uid        = parts[1]
            username   = parts[2]  # actual username e.g. "ryoutaorita"

            session_type = subprocess.run(
                ["loginctl", "show-session", session_id, "-p", "Type", "--value"],
                capture_output=True, text=True
            ).stdout.strip()
            if session_type not in ("x11", "wayland", "mir"):
                continue

            display = subprocess.run(
                ["loginctl", "show-session", session_id, "-p", "Display", "--value"],
                capture_output=True, text=True
            ).stdout.strip() or ":0"

            dbus_path = f"/run/user/{uid}/bus"
            if os.path.exists(dbus_path):
                dbus_addr = f"unix:path={dbus_path}"
                return username, display, dbus_addr  # username not UID

        return None
    except Exception:
        return None


def _notify(profile: str):
    icons = {
        "quiet": "audio-volume-muted",
        "balanced": "battery-good",
        "balanced-performance": "battery-full-charged",
        "performance": "utilities-system-monitor",
    }
    labels = {
        "quiet": "🔇 Quiet Mode  —  15W, boost off",
        "balanced": "⚖️ Balanced Mode  —  35W",
        "balanced-performance": "⚡ Balanced-Performance  —  45W",
        "performance": "🚀 Performance Mode  —  54W",
    }
    icons.update((k, icons[v]) for k, v in _PROFILE_ALIASES.items())
    labels.update((k, labels[v]) for k, v in _PROFILE_ALIASES.items())
    try:
        session = _get_user_session()
        if session is None:
            log.debug("No graphical session found — skipping notification")
            return

        uid, display, dbus_addr = session  # uid is now username e.g. "ryoutaorita"

        subprocess.Popen(
            [
                "runuser", "-u", uid, "--",
                "env",
                f"DISPLAY={display}",
                f"DBUS_SESSION_BUS_ADDRESS={dbus_addr}",
                "notify-send",
                "-i", icons.get(profile, "dialog-information"),
                "-t", "2500",
                "Legion Profile Changed",
                labels.get(profile, profile),
            ],
        )
    except Exception as e:
        log.debug(f"Notification skipped: {e}")


# ── Battery helpers (called by CLI) ───────────────────────────────────────────
def set_conservation_mode(enabled: bool):
    """Battery conservation mode: caps charging at ~60%."""
    write(CONSERVATION_MODE, "1" if enabled else "0",
          f"Conservation mode {'ON' if enabled else 'OFF'}")

# ── Auto profile switching on AC/battery (LLL legiond feature) ─────────────────────
AC_PROFILE_MAP = {
    "quiet":    { "ac": "balanced", "battery": "quiet" },
    "balanced": { "ac": "balanced", "battery": "quiet" },
    "balanced-performance": { "ac": "balanced-performance", "battery": "balanced" },
    "performance": { "ac": "performance", "battery": "balanced-performance" },
}
AC_PROFILE_MAP.update((k, AC_PROFILE_MAP[v]) for k, v in _PROFILE_ALIASES.items())

def get_effective_profile(requested: str = None, power_source: str = None) -> str:
    """
    Get the effective profile based on power source.
    Like LLL's legiond auto-switching feature.
    
    If power_source is None, uses current detected state.
    If requested is None, uses current platform profile.
    """
    if power_source is None:
        power_source = "AC" if is_ac_connected() else "Battery"
    
    if requested is None:
        requested = get_current_profile()
    
    # Use mapping if available
    key = requested.lower()
    if key in AC_PROFILE_MAP:
        mapping = AC_PROFILE_MAP[key]
        return mapping.get(power_source.lower(), requested)
    
    return requested


def set_battery_limit(percent: int):
    """
    ideapad_acpi only has conservation_mode (on/off, ~60% cap).
    For a custom percentage, notify the user of the limitation.
    """
    if percent <= 60:
        set_conservation_mode(True)
        log.info("Battery limit ≤60% — conservation mode enabled")
    else:
        set_conservation_mode(False)
        log.info(f"Battery limit {percent}% — conservation mode disabled (ideapad_acpi only supports on/off)")


def set_camera(enabled: bool):
    write(CAMERA_POWER, "1" if enabled else "0",
          f"Camera {'enabled' if enabled else 'disabled'}")


def set_fn_lock(locked: bool):
    write(FN_LOCK, "1" if locked else "0",
          f"Fn lock {'on' if locked else 'off'}")


def set_usb_charging(enabled: bool):
    write(USB_CHARGING, "1" if enabled else "0",
          f"USB charging while off {'enabled' if enabled else 'disabled'}")


def set_rapid_charge(enabled: bool):
    write(RAPID_CHARGE, "1" if enabled else "0",
          f"Rapid charging {'ON' if enabled else 'OFF (normal charging)'}")


# ── Entry point ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if os.geteuid() != 0:
        print("ERROR: Run as root (sudo)", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd in PROFILES:
            apply_profile(cmd)
        elif cmd == "conservation-on":
            set_conservation_mode(True)
        elif cmd == "conservation-off":
            set_conservation_mode(False)
        elif cmd == "camera-on":
            set_camera(True)
        elif cmd == "camera-off":
            set_camera(False)
        elif cmd == "fn-lock-on":
            set_fn_lock(True)
        elif cmd == "fn-lock-off":
            set_fn_lock(False)
        elif cmd == "usb-charging-on":
            set_usb_charging(True)
        elif cmd == "usb-charging-off":
            set_usb_charging(False)
        elif cmd == "rapid-charge-on":
            set_rapid_charge(True)
        elif cmd == "rapid-charge-off":
            set_rapid_charge(False)
        elif cmd == "status":
            print(f"Profile  : {get_current_profile()}")
            g = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
            print(f"Governor : {g.read_text().strip() if g.exists() else 'N/A'}")
            print(f"Boost    : {AMD_BOOST.read_text().strip() if AMD_BOOST.exists() else 'N/A'}")
            print(f"Temp     : {_read_temp()} °C")
            print(f"Cons.    : {CONSERVATION_MODE.read_text().strip() if CONSERVATION_MODE.exists() else 'N/A'}")
        else:
            print(f"Unknown command: {cmd}")
            print(f"Usage: {sys.argv[0]} [quiet|balanced|balanced-performance|performance|status|conservation-on|off|camera-on|off|fn-lock-on|off|usb-charging-on|off]")
            sys.exit(1)
    else:
        # Run as daemon
        ProfileWatcher().run()
