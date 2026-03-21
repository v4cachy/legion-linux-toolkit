#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Installer  v0.6.1-BETA
# Supports: Legion, LOQ, ThinkPad, ThinkBook, Yoga, IdeaPad
# OS: CachyOS / Arch Linux | Desktop: KDE Plasma 6 Wayland
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
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo      "║   Legion Linux Toolkit — Installer       ║"
echo      "║              v0.6.1-BETA                 ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

# ── Detect Lenovo brand ───────────────────────────────────────────────────────
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
FAMILY=$(cat /sys/class/dmi/id/product_family 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")

if [[ "$VENDOR" != *"lenovo"* ]]; then
    warn "This software is designed for Lenovo laptops."
    warn "Detected vendor: $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo 'Unknown')"
    read -rp "  Continue anyway? [y/N] " yn
    [[ "${yn,,}" == "y" ]] || exit 0
fi

FULL="$PRODUCT $FAMILY"
if   [[ "$FULL" == *"legion"* ]];    then BRAND="Legion"
elif [[ "$FULL" == *"loq"* ]];       then BRAND="LOQ"
elif [[ "$FULL" == *"thinkpad"* ]];  then BRAND="ThinkPad"
elif [[ "$FULL" == *"thinkbook"* ]]; then BRAND="ThinkBook"
elif [[ "$FULL" == *"yoga"* ]];      then BRAND="Yoga"
elif [[ "$FULL" == *"ideapad"* ]];   then BRAND="IdeaPad"
else                                      BRAND="Lenovo"
fi

echo -e "  ${CYAN}Detected:${NC}  $BRAND — $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'Unknown')\n"

# ── 1. Required dependencies ──────────────────────────────────────────────────
echo -e "${BOLD}[1/8] Checking core dependencies…${NC}"

MISSING_PACMAN=()
python3 -c "import PyQt6" 2>/dev/null || MISSING_PACMAN+=("python-pyqt6")
command -v notify-send &>/dev/null     || MISSING_PACMAN+=("libnotify")
pacman -Q qt6-wayland &>/dev/null      || MISSING_PACMAN+=("qt6-wayland")
command -v kscreen-doctor &>/dev/null  || MISSING_PACMAN+=("kscreen")
command -v git &>/dev/null             || MISSING_PACMAN+=("git")

if [[ ${#MISSING_PACMAN[@]} -gt 0 ]]; then
    info "Installing: ${MISSING_PACMAN[*]}"
    pacman -S --noconfirm --needed "${MISSING_PACMAN[@]}" \
        || warn "Some packages failed — continuing"
fi
ok "Core packages ready"

# ── 2. Optional packages by brand ────────────────────────────────────────────
echo -e "\n${BOLD}[2/8] Installing optional packages for $BRAND…${NC}"

# lenovolegionlinux — Legion / LOQ
if [[ "$BRAND" == "Legion" || "$BRAND" == "LOQ" ]]; then
    if ! lsmod 2>/dev/null | grep -q "lenovo_legion"; then
        info "Installing lenovolegionlinux (pacman)…"
        pacman -S --noconfirm --needed lenovolegionlinux lenovolegionlinux-dkms 2>/dev/null \
            && ok "lenovolegionlinux installed" \
            || warn "Not in repos — enable CachyOS repo or install manually"
    else
        ok "lenovo_legion module already loaded"
    fi
fi

# envycontrol — Legion / LOQ (GPU switching)
if [[ "$BRAND" == "Legion" || "$BRAND" == "LOQ" ]]; then
    if ! command -v envycontrol &>/dev/null; then
        if command -v paru &>/dev/null; then
            info "Installing envycontrol (paru)…"
            sudo -u "${REAL_USER:-root}" paru -S --noconfirm envycontrol 2>/dev/null \
                && ok "envycontrol installed" \
                || warn "envycontrol failed — run: paru -S envycontrol"
        else
            warn "paru not found — install envycontrol manually: paru -S envycontrol"
        fi
    else
        ok "envycontrol already installed"
    fi
fi

# legionaura — Legion only (RGB keyboard)
if [[ "$BRAND" == "Legion" ]]; then
    if ! command -v legionaura &>/dev/null; then
        if command -v yay &>/dev/null; then
            info "Installing legionaura (yay)…"
            sudo -u "${REAL_USER:-root}" yay -S --noconfirm legionaura 2>/dev/null \
                && ok "legionaura installed" \
                || warn "legionaura failed — run: yay -S legionaura"
        else
            warn "yay not found — install legionaura manually: yay -S legionaura"
        fi
    else
        ok "legionaura already installed"
    fi
fi

# fprintd — ThinkPad / Yoga (fingerprint)
if [[ "$BRAND" == "ThinkPad" || "$BRAND" == "Yoga" || "$BRAND" == "ThinkBook" ]]; then
    if ! command -v fprintd-enroll &>/dev/null; then
        info "Installing fprintd (fingerprint support)…"
        pacman -S --noconfirm --needed fprintd 2>/dev/null \
            && ok "fprintd installed" \
            || warn "fprintd install failed"
    else
        ok "fprintd already installed"
    fi
fi

# iio-sensor-proxy — Yoga (auto-rotate)
if [[ "$BRAND" == "Yoga" ]]; then
    if ! command -v monitor-sensor &>/dev/null; then
        info "Installing iio-sensor-proxy (auto-rotate)…"
        pacman -S --noconfirm --needed iio-sensor-proxy 2>/dev/null \
            && ok "iio-sensor-proxy installed" \
            || warn "iio-sensor-proxy install failed"
    else
        ok "iio-sensor-proxy already installed"
    fi
fi

# ── 3. Hardware detection ─────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/8] Hardware detection…${NC}"

chk() {
    [[ -e "$2" ]] \
        && echo -e "     ${GREEN}✓${NC}  $1" \
        || echo -e "     ${YELLOW}-${NC}  $1  ${YELLOW}(not found)${NC}"
}

chk "platform_profile (power modes)"          "/sys/firmware/acpi/platform_profile"
chk "ideapad_acpi (battery/camera/fn lock)"   "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00"
chk "fan_fullspeed"                            "/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/fan_fullspeed"
chk "thermalmode"                              "/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/thermalmode"
chk "kbd_backlight (Fn+Space)"                 "/sys/class/leds/platform::kbd_backlight/brightness"

# ThinkPad extras
if [[ "$BRAND" == "ThinkPad" ]]; then
    chk "ThinkPad charge thresholds"           "/sys/class/power_supply/BAT0/charge_start_threshold"
    chk "ThinkPad fan control"                 "/proc/acpi/ibm/fan"
    chk "ThinkLight"                           "/sys/class/leds/tpacpi::thinklight/brightness"
    chk "Mic mute LED"                         "/sys/class/leds/platform::micmute/brightness"
fi

# Yoga extras
if [[ "$BRAND" == "Yoga" ]]; then
    chk "Yoga hinge mode"                      "/sys/bus/platform/drivers/lenovo-ymc"
    chk "Ambient light sensor"                 "/sys/bus/iio/devices"
fi

# Backlight — auto-detect
BL_PATH=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1 || true)
[[ -n "$BL_PATH" ]] \
    && echo -e "     ${GREEN}✓${NC}  display backlight  →  $(dirname "$BL_PATH")" \
    || echo -e "     ${YELLOW}-${NC}  display backlight  ${YELLOW}(not found)${NC}"

# legion_hwmon
HWMON=$(grep -rl "^legion_hwmon$" /sys/class/hwmon/*/name 2>/dev/null \
    | xargs dirname 2>/dev/null | head -1 || true)
[[ -n "$HWMON" ]] \
    && echo -e "     ${GREEN}✓${NC}  legion_hwmon (fan RPM)  →  $HWMON" \
    || echo -e "     ${YELLOW}-${NC}  legion_hwmon  ${YELLOW}(modprobe lenovo_legion_laptop)${NC}"

# ── 4. Daemon ─────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[4/8] Installing daemon…${NC}"
install -d /usr/lib/legion-toolkit
install -m 755 "$SCRIPT_DIR/daemon/legion-daemon.py" /usr/lib/legion-toolkit/legion-daemon.py
install -m 755 "$SCRIPT_DIR/udev/udev-trigger.sh"    /usr/lib/legion-toolkit/udev-trigger.sh
ok "Daemon installed"

# ── 5. CLI ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[5/8] Installing CLI…${NC}"
if [[ -f "$SCRIPT_DIR/scripts/legion-ctl" ]]; then
    install -m 755 "$SCRIPT_DIR/scripts/legion-ctl" /usr/local/bin/legion-ctl
else
    printf '#!/usr/bin/env bash\nexec /usr/lib/legion-toolkit/legion-daemon.py "$@"\n' \
        > /usr/local/bin/legion-ctl
    chmod 755 /usr/local/bin/legion-ctl
fi
ok "CLI → /usr/local/bin/legion-ctl"

# ── 6. udev rules ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[6/8] Installing udev rules…${NC}"
install -m 644 "$SCRIPT_DIR/udev/99-legion-toolkit.rules" /etc/udev/rules.d/
udevadm control --reload-rules && udevadm trigger
ok "udev rules installed and reloaded"

# ── 7. GUI + tray ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[7/8] Installing GUI and tray…${NC}"
install -m 755 "$SCRIPT_DIR/tray/legion-tray.py"  /usr/lib/legion-toolkit/legion-tray.py
install -m 755 "$SCRIPT_DIR/tray/legion-gui.py"   /usr/lib/legion-toolkit/legion-gui.py
install -m 644 "$SCRIPT_DIR/tray/org.legion-toolkit.policy" \
    /usr/share/polkit-1/actions/org.legion-toolkit.policy
install -m 644 "$SCRIPT_DIR/tray/legion-toolkit.desktop" \
    /etc/xdg/autostart/legion-toolkit.desktop
install -m 644 "$SCRIPT_DIR/systemd/legion-toolkit.service" \
    /etc/systemd/system/legion-toolkit.service
systemctl daemon-reload
systemctl enable --now legion-toolkit.service
touch /var/log/legion-toolkit.log && chmod 644 /var/log/legion-toolkit.log
ok "GUI, tray, polkit, autostart, service installed"

# ── 8. Verify + launch ────────────────────────────────────────────────────────
echo -e "\n${BOLD}[8/8] Verifying and launching…${NC}"
sleep 1
systemctl is-active --quiet legion-toolkit.service \
    && ok "Daemon service running" \
    || warn "Daemon not running — journalctl -u legion-toolkit.service"
[[ -S /run/legion-toolkit.sock ]] \
    && ok "Unix socket ready" \
    || warn "Socket not found yet — give it a moment"
PROFILE=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "N/A")
ok "Active profile : $PROFILE"

# Clear first-run flag so wizard shows on next launch
rm -f "${HOME}/.config/legion-toolkit/first_run_done" 2>/dev/null || true
[[ -n "$REAL_USER" ]] && rm -f "/home/${REAL_USER}/.config/legion-toolkit/first_run_done" 2>/dev/null || true

# Auto-launch tray
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
    pgrep -f legion-tray.py > /dev/null \
        && ok "Tray launched — Legion icon visible in system tray" \
        || warn "Tray did not start — check: cat /tmp/legion-tray.log"
else
    warn "Could not detect desktop user — start tray manually:"
    echo -e "     ${CYAN}/usr/lib/legion-toolkit/legion-tray.py &${NC}"
fi

echo -e "\n${GREEN}${BOLD}✓ Installation complete!${NC}"
echo -e "  Brand:   ${CYAN}$BRAND${NC}"
echo    "  Update:  sudo bash update.sh"
echo    "  Logs:    journalctl -fu legion-toolkit.service"
echo    "  Tray:    /tmp/legion-tray.log"
echo    ""
echo    "  The setup wizard will appear when the dashboard opens."
echo    "  It runs once to detect hardware and choose your language."
echo ""
