#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Uninstaller  v0.6.3
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }

# ── Progress Bar ───────────────────────────────────────────────────────────────
BAR_WIDTH=40
TOTAL_STEPS=5
CURRENT_STEP=0

progress() {
    local label="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))
    local filled=$(( (CURRENT_STEP * BAR_WIDTH) / TOTAL_STEPS ))
    local empty=$(( BAR_WIDTH - filled ))

    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"

    printf "\r  ${CYAN}%s${NC}  %3d%% %s  " "$bar" "$pct" "$label"
}

progress_done() {
    echo ""
}

[[ $EUID -ne 0 ]] && exec sudo bash "$0" "$@"

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo      "║   Legion Linux Toolkit — Uninstaller     ║"
echo      "║              v0.6.3                      ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

read -rp "  Remove Legion Linux Toolkit completely? [y/N] " ans
[[ "${ans,,}" == "y" ]] || { echo "  Cancelled."; exit 0; }
echo ""

# ── 1. Stop all running instances ────────────────────────────────────────────
progress "Stopping running instances…"
pkill -f "legion-tray"   2>/dev/null && ok "legion-tray stopped"   || true
pkill -f "legion-gui"    2>/dev/null && ok "legion-gui stopped"    || true
pkill -f "legion-daemon" 2>/dev/null && ok "legion-daemon stopped" || true
sleep 0.5

# ── 2. Systemd service ───────────────────────────────────────────────────────
progress "Removing systemd service…"
systemctl stop    legion-toolkit.service 2>/dev/null || true
systemctl disable legion-toolkit.service 2>/dev/null || true
rm -f /etc/systemd/system/legion-toolkit.service
systemctl daemon-reload
ok "Service removed"

# ── 3. udev rules ────────────────────────────────────────────────────────────
progress "Removing udev rules…"
rm -f /etc/udev/rules.d/99-legion-toolkit.rules
udevadm control --reload-rules && udevadm trigger
ok "udev rules removed"

# ── 4. All installed toolkit files ───────────────────────────────────────────
progress "Removing installed files…"
rm -rf /usr/lib/legion-toolkit
ok "/usr/lib/legion-toolkit removed"

rm -f /usr/local/bin/legion-ctl
ok "legion-ctl removed"

rm -f /usr/share/polkit-1/actions/org.legion-toolkit.policy
ok "Polkit policy removed"

rm -f /etc/xdg/autostart/legion-toolkit.desktop
ok "Autostart entry removed"

rm -f /var/log/legion-toolkit.log
rm -f /run/legion-toolkit.sock 2>/dev/null || true
ok "Logs and socket removed"

# ── 5. Optional: user config ─────────────────────────────────────────────────
echo ""
read -rp "  Remove per-user config and hardware profile? [y/N] " ans2
if [[ "${ans2,,}" == "y" ]]; then
    for homedir in /home/*/; do
        cfg="${homedir}.config/legion-toolkit"
        [[ -d "$cfg" ]] && rm -rf "$cfg" && ok "Removed $cfg"
    done
    [[ -d /root/.config/legion-toolkit ]] && \
        rm -rf /root/.config/legion-toolkit && ok "Removed root config"
else
    warn "User config kept at ~/.config/legion-toolkit"
fi

progress_done

echo -e "\n${GREEN}${BOLD}✓ Legion Linux Toolkit completely removed.${NC}\n"
