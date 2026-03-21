#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Installer
# Hardware: Lenovo Legion 5 15ACH6H | CachyOS / Arch Linux
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "  ${RED}✗${NC}  $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Run as root: sudo bash install.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo      "║   Legion Linux Toolkit — Installer       ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

# ── 1. Required dependencies ──────────────────────────────────────────────────
echo -e "${BOLD}[1/7] Checking dependencies…${NC}"

MISSING_PACMAN=()
MISSING_INFO=()

# Core — required
python3 -c "import PyQt6" 2>/dev/null            || MISSING_PACMAN+=("python-pyqt6")
command -v notify-send &>/dev/null                || MISSING_PACMAN+=("libnotify")

# qt6-wayland — required for KDE Plasma 6 Wayland tray
pacman -Q qt6-wayland &>/dev/null                || MISSING_PACMAN+=("qt6-wayland")

# kscreen — required for resolution / refresh rate control
command -v kscreen-doctor &>/dev/null             || MISSING_PACMAN+=("kscreen")

# Optional — AUR packages
command -v envycontrol &>/dev/null  \
    || MISSING_INFO+=("envycontrol       — GPU mode switching (hybrid/nvidia/integrated)")
command -v legionaura &>/dev/null   \
    || MISSING_INFO+=("legionaura        — keyboard RGB colour control")
lsmod 2>/dev/null | grep -q "lenovo_legion" \
    || MISSING_INFO+=("lenovolegionlinux  — fan RPM, hardware toggles, sysfs paths")

# Install missing pacman packages
if [[ ${#MISSING_PACMAN[@]} -gt 0 ]]; then
    warn "Installing missing packages: ${MISSING_PACMAN[*]}"
    pacman -S --noconfirm --needed "${MISSING_PACMAN[@]}" \
        || warn "Some packages failed — continuing"
fi
ok "Core packages ready"

# ── Install optional packages ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Installing optional packages…${NC}"

# lenovo-legion-linux via pacman
if ! lsmod 2>/dev/null | grep -q "lenovo_legion"; then
    echo -e "  ${CYAN}→${NC}  Installing lenovolegionlinux via pacman…"
    pacman -S --noconfirm --needed lenovolegionlinux lenovolegionlinux-dkms 2>/dev/null \
        && ok "lenovolegionlinux + lenovolegionlinux-dkms installed" \
        || warn "lenovolegionlinux not found in repos — may need CachyOS repo enabled"
else
    ok "lenovo_legion module already loaded"
fi

# envycontrol via paru
if ! command -v envycontrol &>/dev/null; then
    if command -v paru &>/dev/null; then
        echo -e "  ${CYAN}→${NC}  Installing envycontrol via paru…"
        sudo -u "${SUDO_USER:-$USER}" paru -S --noconfirm envycontrol 2>/dev/null \
            && ok "envycontrol installed" \
            || warn "envycontrol install failed — run manually: paru -S envycontrol"
    else
        warn "paru not found — install envycontrol manually: paru -S envycontrol"
    fi
else
    ok "envycontrol already installed"
fi

# legionaura via yay
if ! command -v legionaura &>/dev/null; then
    if command -v yay &>/dev/null; then
        echo -e "  ${CYAN}→${NC}  Installing legionaura via yay…"
        sudo -u "${SUDO_USER:-$USER}" yay -S --noconfirm legionaura 2>/dev/null \
            && ok "legionaura installed" \
            || warn "legionaura install failed — run manually: yay -S legionaura"
    else
        warn "yay not found — install legionaura manually: yay -S legionaura"
    fi
else
    ok "legionaura already installed"
fi

# ── Hardware detection ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Hardware detection:${NC}"

chk() {
    [[ -e "$2" ]] \
        && echo -e "     ${GREEN}✓${NC}  $1" \
        || echo -e "     ${YELLOW}-${NC}  $1  ${YELLOW}(not found)${NC}"
}

chk "platform_profile (power modes)"         "/sys/firmware/acpi/platform_profile"
chk "ideapad_acpi  (battery/camera/fn lock)"  "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00"
chk "fan_fullspeed"                           "/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/fan_fullspeed"
chk "thermalmode"                             "/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/thermalmode"
chk "kbd_backlight  (Fn+Space brightness)"    "/sys/class/leds/platform::kbd_backlight/brightness"
# Backlight — check whichever exists (nvidia_wmi_ec or amdgpu_bl0)
BL_PATH=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1 || true)
[[ -n "$BL_PATH" ]] \
    && echo -e "     ${GREEN}✓${NC}  display backlight  →  $(dirname $BL_PATH)" \
    || echo -e "     ${YELLOW}-${NC}  display backlight  ${YELLOW}(not found)${NC}"

HWMON=$(grep -rl "^legion_hwmon$" /sys/class/hwmon/*/name 2>/dev/null \
    | xargs dirname 2>/dev/null | head -1 || true)
[[ -n "$HWMON" ]] \
    && echo -e "     ${GREEN}✓${NC}  legion_hwmon (fan RPM)  →  $HWMON" \
    || echo -e "     ${YELLOW}-${NC}  legion_hwmon  ${YELLOW}(run: sudo modprobe lenovo_legion_laptop)${NC}"
echo ""

# ── 2. Daemon ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}[2/7] Installing daemon…${NC}"
install -d /usr/lib/legion-toolkit
install -m 755 "$SCRIPT_DIR/daemon/legion-daemon.py" /usr/lib/legion-toolkit/legion-daemon.py
install -m 755 "$SCRIPT_DIR/udev/udev-trigger.sh"    /usr/lib/legion-toolkit/udev-trigger.sh
ok "Daemon installed"

# ── 3. CLI ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[3/7] Installing CLI…${NC}"
if [[ -f "$SCRIPT_DIR/scripts/legion-ctl" ]]; then
    install -m 755 "$SCRIPT_DIR/scripts/legion-ctl" /usr/local/bin/legion-ctl
else
    printf '#!/usr/bin/env bash\nexec /usr/lib/legion-toolkit/legion-daemon.py "$@"\n' \
        > /usr/local/bin/legion-ctl
    chmod 755 /usr/local/bin/legion-ctl
fi
ok "CLI → /usr/local/bin/legion-ctl"

# ── 4. udev rules ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[4/7] Installing udev rules…${NC}"
install -m 644 "$SCRIPT_DIR/udev/99-legion-toolkit.rules" /etc/udev/rules.d/
udevadm control --reload-rules && udevadm trigger
ok "udev rules installed and reloaded"

# ── 5. GUI + tray ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[5/7] Installing GUI and tray…${NC}"
install -m 755 "$SCRIPT_DIR/tray/legion-tray.py"  /usr/lib/legion-toolkit/legion-tray.py
install -m 755 "$SCRIPT_DIR/tray/legion-gui.py"   /usr/lib/legion-toolkit/legion-gui.py
install -m 644 "$SCRIPT_DIR/tray/org.legion-toolkit.policy" \
    /usr/share/polkit-1/actions/org.legion-toolkit.policy
install -m 644 "$SCRIPT_DIR/tray/legion-toolkit.desktop" \
    /etc/xdg/autostart/legion-toolkit.desktop
ok "GUI, tray, polkit, autostart installed"

# ── 6. systemd service ────────────────────────────────────────────────────────
echo -e "${BOLD}[6/7] Enabling systemd service…${NC}"
install -m 644 "$SCRIPT_DIR/systemd/legion-toolkit.service" \
    /etc/systemd/system/legion-toolkit.service
systemctl daemon-reload
systemctl enable --now legion-toolkit.service
touch /var/log/legion-toolkit.log && chmod 644 /var/log/legion-toolkit.log
ok "Service enabled and started"

# ── 7. Verify ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}[7/7] Verifying…${NC}"
sleep 1
systemctl is-active --quiet legion-toolkit.service \
    && ok "Daemon service running" \
    || warn "Daemon not running — journalctl -u legion-toolkit.service"
[[ -S /run/legion-toolkit.sock ]] \
    && ok "Unix socket ready" \
    || warn "Socket not found yet — give it a moment"
PROFILE=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "N/A")
CHOICES=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || echo "N/A")
ok "Active profile  : $PROFILE"
ok "Available       : $CHOICES"

echo -e "\n${GREEN}${BOLD}✓ Installation complete!${NC}\n"

# ── Auto-launch tray as the real desktop user ─────────────────────────────────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -n "$REAL_USER" ]]; then
    REAL_UID=$(id -u "$REAL_USER")
    XDGRT="/run/user/${REAL_UID}"
    WAYLAND_DISP=$(ls "${XDGRT}/wayland-"* 2>/dev/null \
        | head -1 | xargs basename 2>/dev/null || echo "wayland-0")

    info "Launching tray as ${REAL_USER}…"
    sudo -u "$REAL_USER" \
        XDG_RUNTIME_DIR="$XDGRT" \
        WAYLAND_DISPLAY="$WAYLAND_DISP" \
        QT_QPA_PLATFORM="wayland" \
        nohup /usr/lib/legion-toolkit/legion-tray.py \
        > /tmp/legion-tray.log 2>&1 &

    sleep 1
    if pgrep -f legion-tray.py > /dev/null; then
        ok "Tray launched — Legion icon now visible in your system tray"
    else
        warn "Tray did not start — check: cat /tmp/legion-tray.log"
    fi
else
    warn "Could not detect desktop user — start tray manually:"
    echo -e "     ${CYAN}/usr/lib/legion-toolkit/legion-tray.py &${NC}"
fi

echo ""
echo    "  Update:  sudo bash update.sh"
echo    "  Logs:    journalctl -fu legion-toolkit.service"
echo ""
