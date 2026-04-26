#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Installer  v0.6.2
# Supports: Legion, LOQ, ThinkPad, ThinkBook, Yoga, IdeaPad
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
echo      "║              v0.6.2                      ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

# ── Detect Lenovo brand ───────────────────────────────────────────────────────
PRODUCT=$(cat /sys/class/dmi/id/product_name   2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
FAMILY=$(cat  /sys/class/dmi/id/product_family 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
VENDOR=$(cat  /sys/class/dmi/id/sys_vendor     2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")

if [[ "$VENDOR" != *"lenovo"* ]]; then
    warn "This software is designed for Lenovo laptops."
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
else                                       BRAND="Lenovo"
fi

echo -e "  ${CYAN}Detected:${NC}  $BRAND — $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'Unknown')\n"

# ── 1. Core dependencies ──────────────────────────────────────────────────────
echo -e "${BOLD}[1/8] Checking core dependencies…${NC}"
MISSING_PACMAN=()
python3 -c "import PyQt6" 2>/dev/null      || MISSING_PACMAN+=("python-pyqt6")
command -v notify-send &>/dev/null         || MISSING_PACMAN+=("libnotify")
pacman -Q qt6-wayland &>/dev/null         || MISSING_PACMAN+=("qt6-wayland")
command -v kscreen-doctor &>/dev/null     || MISSING_PACMAN+=("kscreen")
command -v git &>/dev/null                || MISSING_PACMAN+=("git")
[[ ${#MISSING_PACMAN[@]} -gt 0 ]] && pacman -S --noconfirm --needed "${MISSING_PACMAN[@]}"
ok "Core packages ready"

# ── 2. Brand-specific optional packages ──────────────────────────────────────
echo -e "\n${BOLD}[2/8] Installing optional packages for $BRAND…${NC}"
if [[ "$BRAND" == "Legion" || "$BRAND" == "LOQ" ]]; then
    if ! lsmod 2>/dev/null | grep -q "lenovo_legion"; then
        pacman -S --noconfirm --needed lenovolegionlinux lenovolegionlinux-dkms 2>/dev/null \
            && ok "lenovolegionlinux installed" || warn "Not in repos — skip"
        modprobe legion_laptop 2>/dev/null || true; sleep 1
    else
        ok "lenovo_legion already loaded"
    fi
    if dmesg 2>/dev/null | grep -q "probe with driver legion failed\|Could not init ACPI access"; then
        echo 'options legion_laptop force=1' > /etc/modprobe.d/legion_laptop_force.conf
        modprobe -r legion_laptop 2>/dev/null || true
        modprobe legion_laptop force=1 2>/dev/null && ok "Force-load applied" || warn "Force-load failed"
    fi
    if ! command -v envycontrol &>/dev/null; then
        if command -v paru &>/dev/null; then
            sudo -u "${REAL_USER:-root}" paru -S --noconfirm envycontrol 2>/dev/null \
                && ok "envycontrol installed" \
                || warn "envycontrol install failed — run: paru -S envycontrol"
        else
            warn "paru not found — install envycontrol manually: paru -S envycontrol"
        fi
    else
        ok "envycontrol already installed"
    fi
    # Symlink to /usr/local/bin so daemon (root) can always find it
    ENV_BIN=$(command -v envycontrol 2>/dev/null || true)
    if [[ -n "$ENV_BIN" && ! -f "/usr/local/bin/envycontrol" ]]; then
        ln -sf "$ENV_BIN" /usr/local/bin/envycontrol
        ok "envycontrol symlinked → /usr/local/bin/envycontrol"
    fi
fi
if [[ "$BRAND" == "ThinkPad" || "$BRAND" == "Yoga" || "$BRAND" == "ThinkBook" ]]; then
    command -v fprintd-enroll &>/dev/null \
        || pacman -S --noconfirm --needed fprintd 2>/dev/null && ok "fprintd ready" || true
fi
if [[ "$BRAND" == "Yoga" ]]; then
    command -v monitor-sensor &>/dev/null \
        || pacman -S --noconfirm --needed iio-sensor-proxy 2>/dev/null && ok "iio-sensor-proxy ready" || true
fi

# ── 3. Hardware detection ─────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/8] Hardware detection…${NC}"
chk() { [[ -e "$2" ]] && echo -e "     ${GREEN}✓${NC}  $1" || echo -e "     ${YELLOW}-${NC}  $1 (not found)"; }
chk "platform_profile"  "/sys/firmware/acpi/platform_profile"
chk "ideapad_acpi"      "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00"
chk "kbd_backlight"     "/sys/class/leds/platform::kbd_backlight/brightness"
BL=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1 || true)
[[ -n "$BL" ]] && echo -e "     ${GREEN}✓${NC}  backlight → $(dirname "$BL")" \
               || echo -e "     ${YELLOW}-${NC}  backlight not found"

# ── 4. Stop any existing instances ───────────────────────────────────────────
echo -e "\n${BOLD}[4/8] Stopping existing instances…${NC}"
pkill -f "legion-tray"   2>/dev/null && info "Stopped tray"   || true
pkill -f "legion-gui"    2>/dev/null && info "Stopped gui"    || true
systemctl stop legion-toolkit.service 2>/dev/null && info "Stopped daemon" || true
sleep 0.5

# ── 5. Install daemon ─────────────────────────────────────────────────────────
echo -e "${BOLD}[5/8] Installing daemon…${NC}"
mkdir -p /usr/lib/legion-toolkit
install -m 755 "$SCRIPT_DIR/daemon/legion-daemon.py" /usr/lib/legion-toolkit/legion-daemon.py
install -m 755 "$SCRIPT_DIR/udev/udev-trigger.sh"    /usr/lib/legion-toolkit/udev-trigger.sh
ok "Daemon installed"

# ── 6. Install CLI ────────────────────────────────────────────────────────────
echo -e "${BOLD}[6/8] Installing CLI…${NC}"
if [[ -f "$SCRIPT_DIR/scripts/legion-ctl" ]]; then
    install -m 755 "$SCRIPT_DIR/scripts/legion-ctl" /usr/local/bin/legion-ctl
else
    printf '#!/usr/bin/env bash\nexec /usr/lib/legion-toolkit/legion-daemon.py "$@"\n' \
        > /usr/local/bin/legion-ctl && chmod 755 /usr/local/bin/legion-ctl
fi
ok "CLI installed → /usr/local/bin/legion-ctl"

# ── 7. Install GUI + tray ─────────────────────────────────────────────────────
echo -e "${BOLD}[7/8] Installing GUI and tray…${NC}"
install -m 755 "$SCRIPT_DIR/tray/legion-gui.py"  /usr/lib/legion-toolkit/legion-gui.py
install -m 755 "$SCRIPT_DIR/tray/legion-tray.py" /usr/lib/legion-toolkit/legion-tray.py
install -m 644 "$SCRIPT_DIR/tray/kernel_check.py" /usr/lib/legion-toolkit/kernel_check.py
install -m 644 "$SCRIPT_DIR/tray/org.legion-toolkit.policy" \
    /usr/share/polkit-1/actions/org.legion-toolkit.policy
ok "GUI and tray installed"

TRAY_EXEC="/usr/lib/legion-toolkit/legion-tray.py"
cat > /etc/xdg/autostart/legion-toolkit.desktop << EOF
[Desktop Entry]
Type=Application
Name=Legion Linux Toolkit
Exec=pkexec $TRAY_EXEC
Icon=computer
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF
ok "Autostart configured (using pkexec)"

# ── 8. udev + systemd ─────────────────────────────────────────────────────────
echo -e "${BOLD}[8/8] Installing udev rules and service…${NC}"
install -m 644 "$SCRIPT_DIR/udev/99-legion-toolkit.rules" /etc/udev/rules.d/
udevadm control --reload-rules && udevadm trigger
ok "udev rules installed"

install -m 644 "$SCRIPT_DIR/systemd/legion-toolkit.service" \
    /etc/systemd/system/legion-toolkit.service
systemctl daemon-reload
systemctl enable --now legion-toolkit.service
touch /var/log/legion-toolkit.log && chmod 644 /var/log/legion-toolkit.log
ok "Service enabled and started"

# ── Verify + launch ───────────────────────────────────────────────────────────
echo -e "\n${BOLD}Verifying and launching…${NC}"
sleep 1
systemctl is-active --quiet legion-toolkit.service \
    && ok "Daemon running" \
    || warn "Daemon not running — journalctl -u legion-toolkit.service"

# Reset first-run flag so wizard shows on next launch
[[ -n "$REAL_USER" ]] && \
    rm -f "/home/${REAL_USER}/.config/legion-toolkit/first_run_done" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}✓ Installation complete!${NC}"
echo -e "  Brand : ${CYAN}$BRAND${NC}"
echo    "  Update: sudo bash update.sh"
echo    "  Logs  : journalctl -fu legion-toolkit.service"
echo    "  Tray  : Run 'legion-toolkit' or reboot to start automatically"
echo ""
