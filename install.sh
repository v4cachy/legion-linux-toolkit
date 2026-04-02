#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Installer  v0.6.1-BETA
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
echo      "║              v0.6.1-BETA                 ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

# ── Detect Lenovo brand ───────────────────────────────────────────────────────
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
FAMILY=$(cat /sys/class/dmi/id/product_family 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")

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
echo -e "${BOLD}[1/9] Checking core dependencies…${NC}"
MISSING_PACMAN=()
python3 -c "import PyQt6" 2>/dev/null || MISSING_PACMAN+=("python-pyqt6")
command -v notify-send &>/dev/null     || MISSING_PACMAN+=("libnotify")
pacman -Q qt6-wayland &>/dev/null      || MISSING_PACMAN+=("qt6-wayland")
command -v kscreen-doctor &>/dev/null  || MISSING_PACMAN+=("kscreen")
command -v git &>/dev/null             || MISSING_PACMAN+=("git")
command -v patchelf &>/dev/null        || MISSING_PACMAN+=("patchelf")
[[ ${#MISSING_PACMAN[@]} -gt 0 ]] && pacman -S --noconfirm --needed "${MISSING_PACMAN[@]}" || true
ok "Core packages ready"

# ── 2. Brand-specific optional packages ──────────────────────────────────────
echo -e "\n${BOLD}[2/9] Installing optional packages for $BRAND…${NC}"
if [[ "$BRAND" == "Legion" || "$BRAND" == "LOQ" ]]; then
    if ! lsmod 2>/dev/null | grep -q "lenovo_legion"; then
        pacman -S --noconfirm --needed lenovolegionlinux lenovolegionlinux-dkms 2>/dev/null \
            && ok "lenovolegionlinux installed" || warn "Not in repos"
        modprobe legion_laptop 2>/dev/null || true; sleep 1
    else ok "lenovo_legion already loaded"; fi
    if dmesg 2>/dev/null | grep -q "probe with driver legion failed\|Could not init ACPI access"; then
        echo 'options legion_laptop force=1' > /etc/modprobe.d/legion_laptop_force.conf
        modprobe -r legion_laptop 2>/dev/null || true
        modprobe legion_laptop force=1 2>/dev/null && ok "Force-load applied" || warn "Force-load failed"
    fi
    ! command -v envycontrol &>/dev/null && command -v paru &>/dev/null \
        && sudo -u "${REAL_USER:-root}" paru -S --noconfirm envycontrol 2>/dev/null \
        && ok "envycontrol installed" || true
fi
if [[ "$BRAND" == "Legion" ]]; then
    ! command -v legionaura &>/dev/null && command -v yay &>/dev/null \
        && sudo -u "${REAL_USER:-root}" yay -S --noconfirm legionaura 2>/dev/null \
        && ok "legionaura installed" || true
fi
if [[ "$BRAND" == "ThinkPad" || "$BRAND" == "Yoga" || "$BRAND" == "ThinkBook" ]]; then
    command -v fprintd-enroll &>/dev/null || pacman -S --noconfirm --needed fprintd 2>/dev/null && ok "fprintd ready" || true
fi
if [[ "$BRAND" == "Yoga" ]]; then
    command -v monitor-sensor &>/dev/null || pacman -S --noconfirm --needed iio-sensor-proxy 2>/dev/null && ok "iio-sensor-proxy ready" || true
fi

# ── 3. Hardware detection ─────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/9] Hardware detection…${NC}"
chk() { [[ -e "$2" ]] && echo -e "     ${GREEN}✓${NC}  $1" || echo -e "     ${YELLOW}-${NC}  $1"; }
chk "platform_profile"  "/sys/firmware/acpi/platform_profile"
chk "ideapad_acpi"      "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00"
chk "kbd_backlight"     "/sys/class/leds/platform::kbd_backlight/brightness"
BL=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1 || true)
[[ -n "$BL" ]] && echo -e "     ${GREEN}✓${NC}  backlight → $(dirname "$BL")" \
               || echo -e "     ${YELLOW}-${NC}  backlight not found"

# ── 4. Build standalone binaries ─────────────────────────────────────────────
echo -e "\n${BOLD}[4/9] Building standalone binaries (PyInstaller)…${NC}"
DIST="$SCRIPT_DIR/dist"
BUILD_OK=false

if [[ -f "$DIST/legion-gui" && -f "$DIST/legion-tray" ]]; then
    ok "Pre-built binaries found in dist/ — skipping build"
    BUILD_OK=true
else
    # Install PyInstaller
    if ! python3 -m PyInstaller --version &>/dev/null 2>&1; then
        info "Installing PyInstaller…"
        pip install pyinstaller --break-system-packages 2>/dev/null || true
    fi

    if python3 -m PyInstaller --version &>/dev/null 2>&1; then
        info "Building binaries via PyInstaller (2–5 min)…"
        bash "$SCRIPT_DIR/build.sh"             && BUILD_OK=true             || warn "Build failed — falling back to Python scripts"
    else
        warn "PyInstaller unavailable — using Python scripts (run 'bash build.sh' later)"
    fi
fi

# ── 5. Daemon ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}[5/9] Installing daemon…${NC}"
install -d /usr/lib/legion-toolkit
install -m 755 "$SCRIPT_DIR/daemon/legion-daemon.py" /usr/lib/legion-toolkit/legion-daemon.py
install -m 755 "$SCRIPT_DIR/udev/udev-trigger.sh"    /usr/lib/legion-toolkit/udev-trigger.sh
ok "Daemon installed"

# ── 6. CLI ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[6/9] Installing CLI…${NC}"
if [[ -f "$SCRIPT_DIR/scripts/legion-ctl" ]]; then
    install -m 755 "$SCRIPT_DIR/scripts/legion-ctl" /usr/local/bin/legion-ctl
else
    printf '#!/usr/bin/env bash\nexec /usr/lib/legion-toolkit/legion-daemon.py "$@"\n' \
        > /usr/local/bin/legion-ctl && chmod 755 /usr/local/bin/legion-ctl
fi
ok "CLI installed"

# ── 7. GUI + tray ─────────────────────────────────────────────────────────────
echo -e "${BOLD}[7/9] Installing GUI and tray…${NC}"
# Always install Python scripts (source + daemon reference)
install -m 755 "$SCRIPT_DIR/tray/legion-gui.py"  /usr/lib/legion-toolkit/legion-gui.py
install -m 755 "$SCRIPT_DIR/tray/legion-tray.py" /usr/lib/legion-toolkit/legion-tray.py

if [[ "$BUILD_OK" == true ]]; then
    install -m 755 "$DIST/legion-gui"  /usr/lib/legion-toolkit/legion-gui
    install -m 755 "$DIST/legion-tray" /usr/lib/legion-toolkit/legion-tray
    TRAY_EXEC="/usr/lib/legion-toolkit/legion-tray"
    TRAY_PGREP="legion-tray"
    ok "Standalone binaries installed"
else
    TRAY_EXEC="/usr/lib/legion-toolkit/legion-tray.py"
    TRAY_PGREP="legion-tray.py"
    ok "Python scripts installed"
fi

install -m 644 "$SCRIPT_DIR/tray/org.legion-toolkit.policy" \
    /usr/share/polkit-1/actions/org.legion-toolkit.policy

# Autostart points to correct binary
cat > /etc/xdg/autostart/legion-toolkit.desktop << EOF
[Desktop Entry]
Type=Application
Name=Legion Linux Toolkit
Exec=$TRAY_EXEC
Icon=computer
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF
ok "Autostart configured → $TRAY_EXEC"

# ── 8. udev + systemd ─────────────────────────────────────────────────────────
echo -e "${BOLD}[8/9] Installing udev rules and service…${NC}"
install -m 644 "$SCRIPT_DIR/udev/99-legion-toolkit.rules" /etc/udev/rules.d/
udevadm control --reload-rules && udevadm trigger
install -m 644 "$SCRIPT_DIR/systemd/legion-toolkit.service" \
    /etc/systemd/system/legion-toolkit.service
systemctl daemon-reload && systemctl enable --now legion-toolkit.service
touch /var/log/legion-toolkit.log && chmod 644 /var/log/legion-toolkit.log
ok "udev rules and service installed"

# ── 9. Verify + launch ────────────────────────────────────────────────────────
echo -e "\n${BOLD}[9/9] Verifying and launching…${NC}"
sleep 1
systemctl is-active --quiet legion-toolkit.service && ok "Daemon running" \
    || warn "Daemon not running — journalctl -u legion-toolkit.service"
rm -f "/home/${REAL_USER}/.config/legion-toolkit/first_run_done" 2>/dev/null || true

if [[ -n "$REAL_USER" ]]; then
    REAL_UID=$(id -u "$REAL_USER")
    XDGRT="/run/user/${REAL_UID}"
    WDISP=$(ls "${XDGRT}/wayland-"* 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "wayland-0")
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="$XDGRT" WAYLAND_DISPLAY="$WDISP" \
        QT_QPA_PLATFORM="wayland" nohup "$TRAY_EXEC" > /tmp/legion-tray.log 2>&1 &
    sleep 1
    pgrep -f "$TRAY_PGREP" > /dev/null \
        && ok "Tray launched" || warn "Tray did not start — cat /tmp/legion-tray.log"
fi

echo -e "\n${GREEN}${BOLD}✓ Installation complete!${NC}"
echo -e "  Brand : ${CYAN}$BRAND${NC}"
[[ "$BUILD_OK" == true ]] \
    && echo "  Mode  : Standalone binaries (lower RAM ✓)" \
    || echo "  Mode  : Python scripts — run 'bash build.sh' to compile binaries"
echo "  Update: sudo bash update.sh"
echo ""
