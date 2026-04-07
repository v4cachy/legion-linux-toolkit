#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — Updater  v0.6.1-BETA
# Pulls latest from GitHub, rebuilds binaries if source changed, reinstalls.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "  ${RED}✗${NC}  $*"; exit 1; }

[[ $EUID -ne 0 ]] && exec sudo bash "$0" "$@"

REPO_URL="https://github.com/v4cachy/legion-linux-toolkit"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo      "║   Legion Linux Toolkit — Updater         ║"
echo      "║              v0.6.1-BETA                 ║"
echo -e   "╚══════════════════════════════════════════╝"
echo -e "  Repo: ${CYAN}${REPO_URL}${NC}\n"

# ── 1. Pull from GitHub ───────────────────────────────────────────────────────
echo -e "${BOLD}[1/4] Pulling latest from GitHub…${NC}"
command -v git &>/dev/null || err "git not found — sudo pacman -S git"

if [[ -d "$SCRIPT_DIR/.git" ]]; then
    cd "$SCRIPT_DIR"
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    git fetch origin 2>&1 | while IFS= read -r line; do
        echo -e "     ${CYAN}git${NC}  $line"
    done
    git reset --hard origin/main 2>/dev/null \
        || git reset --hard origin/master 2>/dev/null \
        || warn "Could not reset"
    AFTER=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    if [[ "$BEFORE" == "$AFTER" ]]; then
        ok "Already up to date"
    else
        info "Changes pulled:"
        git log --oneline "${BEFORE}..${AFTER}" 2>/dev/null | while IFS= read -r line; do
            echo -e "     ${GREEN}•${NC}  $line"
        done
        # Check if Python source files changed — triggers rebuild
        if git diff --name-only "${BEFORE}..${AFTER}" 2>/dev/null \
                | grep -q "tray/legion-gui.py\|tray/legion-tray.py"; then
            SOURCE_CHANGED=true
            info "Source files changed — binaries will be rebuilt"
        fi
        echo ""
    fi
else
    warn "Not a git repo — cloning fresh…"
    TMPDIR=$(mktemp -d); trap "rm -rf $TMPDIR" EXIT
    git clone --depth=1 "$REPO_URL" "$TMPDIR/legion-toolkit" 2>&1 | tail -3
    rsync -a --exclude='.git' "$TMPDIR/legion-toolkit/" "$SCRIPT_DIR/" \
        || cp -r "$TMPDIR/legion-toolkit/." "$SCRIPT_DIR/"
fi

# ── 3. Stop running instances ─────────────────────────────────────────────────
echo -e "${BOLD}[2/4] Stopping running instances…${NC}"
pkill -f "legion-tray"   2>/dev/null && info "Stopped tray"   || true
pkill -f "legion-gui"    2>/dev/null && info "Stopped gui"    || true
pkill -f "legion-daemon" 2>/dev/null && info "Stopped daemon" || true
sleep 0.4

# ── 4. Install updated files ──────────────────────────────────────────────────
echo -e "${BOLD}[3/4] Installing updated files…${NC}"

install_file() {
    local src="$1" dst="$2" mode="${3:-644}"
    [[ -f "$src" ]] || { warn "Skipping: $src"; return; }
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst" && chmod "$mode" "$dst"
    ok "$(basename "$src") → $dst"
}

mkdir -p /usr/lib/legion-toolkit

install_file "$SCRIPT_DIR/daemon/legion-daemon.py"           /usr/lib/legion-toolkit/legion-daemon.py       755
install_file "$SCRIPT_DIR/udev/udev-trigger.sh"              /usr/lib/legion-toolkit/udev-trigger.sh        755
install_file "$SCRIPT_DIR/tray/legion-gui.py"                /usr/lib/legion-toolkit/legion-gui.py          755
install_file "$SCRIPT_DIR/tray/legion-tray.py"               /usr/lib/legion-toolkit/legion-tray.py         755
install_file "$SCRIPT_DIR/tray/org.legion-toolkit.policy"    /usr/share/polkit-1/actions/org.legion-toolkit.policy  644
install_file "$SCRIPT_DIR/systemd/legion-toolkit.service"    /etc/systemd/system/legion-toolkit.service     644
[[ -f "$SCRIPT_DIR/scripts/legion-ctl" ]] && install_file "$SCRIPT_DIR/scripts/legion-ctl" /usr/local/bin/legion-ctl 755
[[ -f "$SCRIPT_DIR/udev/99-legion-toolkit.rules" ]] && {
    install_file "$SCRIPT_DIR/udev/99-legion-toolkit.rules" /etc/udev/rules.d/99-legion-toolkit.rules 644
    udevadm control --reload-rules && udevadm trigger && ok "udev rules reloaded"
}

TRAY_EXEC="/usr/lib/legion-toolkit/legion-tray.py"
TRAY_PGREP="legion-tray.py"

# Update autostart
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

# ── 5. Restart services ───────────────────────────────────────────────────────
echo -e "${BOLD}[4/4] Restarting services…${NC}"
systemctl daemon-reload
systemctl is-enabled --quiet legion-toolkit.service 2>/dev/null \
    && systemctl restart legion-toolkit.service && ok "Daemon restarted" \
    || warn "Service restart failed"

if [[ -n "$REAL_USER" ]]; then
    REAL_UID=$(id -u "$REAL_USER")
    XDGRT="/run/user/${REAL_UID}"
    WDISP=$(ls "${XDGRT}/wayland-"* 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "wayland-0")
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="$XDGRT" WAYLAND_DISPLAY="$WDISP" \
        QT_QPA_PLATFORM="wayland" nohup "$TRAY_EXEC" > /tmp/legion-tray.log 2>&1 &
    sleep 0.8
    pgrep -f "$TRAY_PGREP" > /dev/null \
        && ok "Tray started (user: $REAL_USER)" \
        || warn "Tray may not have started — check /tmp/legion-tray.log"
fi

echo -e "\n${GREEN}${BOLD}✓ Update complete!${NC}"
VER=$(cd "$SCRIPT_DIR" 2>/dev/null && git describe --tags --always 2>/dev/null \
    || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo -e "  Version : ${CYAN}${VER}${NC}"
echo    "  Tray log: /tmp/legion-tray.log"
echo -e "  Daemon  : journalctl -fu legion-toolkit.service\n"
