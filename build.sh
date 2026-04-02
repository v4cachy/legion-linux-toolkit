#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Legion Linux Toolkit — PyInstaller Build Script
# Compiles legion-gui.py and legion-tray.py into standalone binaries
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "  ${RED}✗${NC}  $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/_build_tmp"

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo      "║   Legion Linux Toolkit — Build           ║"
echo      "║   PyInstaller → Standalone Binaries      ║"
echo -e   "╚══════════════════════════════════════════╝${NC}\n"

# ── 1. Install PyInstaller ────────────────────────────────────────────────────
echo -e "${BOLD}[1/4] Checking PyInstaller…${NC}"
if ! python3 -m PyInstaller --version &>/dev/null 2>&1; then
    info "Installing PyInstaller…"
    pip install pyinstaller --break-system-packages \
        || err "Failed — try: pip install pyinstaller --break-system-packages"
fi
VER=$(python3 -m PyInstaller --version 2>/dev/null)
ok "PyInstaller $VER ready"

# ── 2. Prepare ────────────────────────────────────────────────────────────────
echo -e "${BOLD}[2/4] Preparing…${NC}"
mkdir -p "$DIST" "$BUILD_DIR"

# Find PyQt6 location for hooks
PYQT6_PATH=$(python3 -c "import PyQt6; import os; print(os.path.dirname(PyQt6.__file__))" 2>/dev/null || echo "")
[[ -n "$PYQT6_PATH" ]] && ok "PyQt6 found at $PYQT6_PATH" || warn "PyQt6 path not found"

# Common PyInstaller flags
COMMON=(
    --onefile
    --noconfirm
    --clean
    --distpath "$DIST"
    --workpath "$BUILD_DIR"
    --specpath "$BUILD_DIR"
    --hidden-import=PyQt6
    --hidden-import=PyQt6.QtWidgets
    --hidden-import=PyQt6.QtCore
    --hidden-import=PyQt6.QtGui
    --collect-all=PyQt6
    --exclude-module=tkinter
    --exclude-module=unittest
    --exclude-module=email
    --exclude-module=xml
    --exclude-module=pydoc
    --log-level=WARN
)

[[ -f "$SCRIPT_DIR/logo.png" ]] && COMMON+=(--icon="$SCRIPT_DIR/logo.png")

# ── 3. Build legion-gui ───────────────────────────────────────────────────────
echo -e "${BOLD}[3/4] Building legion-gui…${NC}"
info "This takes 2–5 minutes…"

python3 -m PyInstaller \
    "${COMMON[@]}" \
    --name legion-gui \
    --windowed \
    "$SCRIPT_DIR/tray/legion-gui.py"

if [[ -f "$DIST/legion-gui" ]]; then
    chmod +x "$DIST/legion-gui"
    SIZE=$(du -sh "$DIST/legion-gui" | cut -f1)
    ok "legion-gui  →  $DIST/legion-gui  ($SIZE)"
else
    err "legion-gui build failed"
fi

# ── 4. Build legion-tray ──────────────────────────────────────────────────────
echo -e "${BOLD}[4/4] Building legion-tray…${NC}"
info "This takes 1–3 minutes…"

python3 -m PyInstaller \
    "${COMMON[@]}" \
    --name legion-tray \
    "$SCRIPT_DIR/tray/legion-tray.py"

if [[ -f "$DIST/legion-tray" ]]; then
    chmod +x "$DIST/legion-tray"
    SIZE=$(du -sh "$DIST/legion-tray" | cut -f1)
    ok "legion-tray  →  $DIST/legion-tray  ($SIZE)"
else
    err "legion-tray build failed"
fi

# Cleanup build temp
rm -rf "$BUILD_DIR"

echo -e "\n${GREEN}${BOLD}✓ Build complete!${NC}"
echo ""
ls -lh "$DIST/legion-gui" "$DIST/legion-tray" 2>/dev/null | \
    awk '{print "  " $NF "  " $5}'
echo ""
echo    "  Test:"
echo -e "    ${CYAN}$DIST/legion-tray &${NC}"
echo -e "    ${CYAN}$DIST/legion-gui${NC}"
echo ""
echo    "  Install built binaries:"
echo -e "    ${CYAN}sudo bash install.sh${NC}  (auto-detects and installs them)"
echo ""
