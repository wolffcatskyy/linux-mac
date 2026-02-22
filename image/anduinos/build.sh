#!/bin/bash
# =============================================================================
# AnduinOS Mac Pro 6,1 ISO Builder
# =============================================================================
# Builds a pre-configured AnduinOS (Ubuntu LTS + GNOME) ISO with:
#   - Custom linux-macpro61 kernel
#   - Mesa 26.1-dev with RADV Vulkan
#   - macOS Tahoe KVM one-click setup
#   - Fan control and sysctl tuning
#
# Requirements: AMD64 Linux host with debootstrap, live-build, squashfs-tools,
#               xorriso, mtools, grub-efi-amd64-bin
#
# Usage: sudo ./build.sh [--kernel-deb /path/to/linux-macpro61.deb]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$SCRIPT_DIR/../common"
DIST_DIR="$SCRIPT_DIR/dist"
WORK_DIR="$SCRIPT_DIR/work"
BUILD_DATE=$(date +%Y%m%d)
ISO_NAME="linux-mac-anduinos-${BUILD_DATE}.iso"

# AnduinOS upstream
ANDUINOS_REPO="https://github.com/Anduin2017/AnduinOS.git"
ANDUINOS_BRANCH="main"

# --- Parse args ---------------------------------------------------------------
KERNEL_DEB=""
MESA_DEBS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-deb) KERNEL_DEB="$2"; shift 2 ;;
        --mesa-debs)  MESA_DEBS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Preflight ----------------------------------------------------------------
echo "================================================================"
echo "  AnduinOS Mac Pro 6,1 ISO Builder"
echo "================================================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root (need chroot access)"
    exit 1
fi

for cmd in debootstrap xorriso mtools squashfs-tools; do
    if ! command -v "$cmd" &>/dev/null && ! dpkg -l "$cmd" &>/dev/null 2>&1; then
        echo "WARNING: $cmd may not be installed"
    fi
done

mkdir -p "$DIST_DIR" "$WORK_DIR"

# --- Step 1: Clone AnduinOS build system --------------------------------------
echo ""
echo "[1/7] Cloning AnduinOS build system..."

if [ ! -d "$WORK_DIR/AnduinOS" ]; then
    git clone --depth 1 -b "$ANDUINOS_BRANCH" "$ANDUINOS_REPO" "$WORK_DIR/AnduinOS"
else
    echo "  Already cloned, pulling latest..."
    cd "$WORK_DIR/AnduinOS" && git pull || true
fi

# --- Step 2: Inject custom kernel ---------------------------------------------
echo ""
echo "[2/7] Injecting custom kernel..."

if [ -n "$KERNEL_DEB" ] && [ -f "$KERNEL_DEB" ]; then
    echo "  Using provided kernel: $KERNEL_DEB"
    mkdir -p "$WORK_DIR/custom-debs"
    cp "$KERNEL_DEB" "$WORK_DIR/custom-debs/"
else
    echo "  No --kernel-deb provided."
    echo "  To build: cd packaging/arch && makepkg -s"
    echo "  Then convert to .deb with alien, or build natively on Ubuntu."
    echo ""
    echo "  For now, building without custom kernel."
    echo "  The ISO will use stock Ubuntu kernel (add custom kernel post-install)."
fi

# --- Step 3: Inject Mesa 26.1-dev --------------------------------------------
echo ""
echo "[3/7] Injecting Mesa 26.1-dev..."

if [ -n "$MESA_DEBS" ] && [ -d "$MESA_DEBS" ]; then
    echo "  Using Mesa debs from: $MESA_DEBS"
    cp "$MESA_DEBS"/*.deb "$WORK_DIR/custom-debs/" 2>/dev/null || true
else
    echo "  No --mesa-debs provided."
    echo "  The ISO will use Ubuntu's Mesa packages."
    echo "  For GCN 1.0, consider adding Oibaf PPA or building from git."
fi

# --- Step 4: Add macOS Tahoe KVM toolkit --------------------------------------
echo ""
echo "[4/7] Adding macOS Tahoe KVM toolkit..."

# This will be copied into the chroot during build
TAHOE_DIR="$PROJECT_ROOT/macos-tahoe-kvm"
if [ -d "$TAHOE_DIR" ]; then
    echo "  Found toolkit at $TAHOE_DIR"
else
    echo "  WARNING: macOS Tahoe KVM toolkit not found at $TAHOE_DIR"
fi

# --- Step 5: Prepare overlay --------------------------------------------------
echo ""
echo "[5/7] Preparing filesystem overlay..."

OVERLAY_DIR="$WORK_DIR/overlay"
rm -rf "$OVERLAY_DIR"
mkdir -p "$OVERLAY_DIR"

# Copy common overlay
cp -r "$COMMON_DIR/overlay/"* "$OVERLAY_DIR/" 2>/dev/null || true

# Copy macOS Tahoe KVM toolkit
if [ -d "$TAHOE_DIR" ]; then
    mkdir -p "$OVERLAY_DIR/opt/macos-tahoe-kvm"
    cp -r "$TAHOE_DIR/scripts" "$OVERLAY_DIR/opt/macos-tahoe-kvm/"
    cp -r "$TAHOE_DIR/ISO-INTEGRATION.md" "$OVERLAY_DIR/opt/macos-tahoe-kvm/" 2>/dev/null || true
    chmod +x "$OVERLAY_DIR/opt/macos-tahoe-kvm/scripts/"*.sh 2>/dev/null || true
fi

# Copy OpenCore.qcow2 if available
if [ -f "$TAHOE_DIR/opencore-efi/OpenCore.qcow2" ]; then
    mkdir -p "$OVERLAY_DIR/opt/macos-tahoe-kvm/opencore-efi"
    cp "$TAHOE_DIR/opencore-efi/OpenCore.qcow2" "$OVERLAY_DIR/opt/macos-tahoe-kvm/opencore-efi/"
    echo "  OpenCore.qcow2 included"
fi

# Create first-boot service for desktop launcher
mkdir -p "$OVERLAY_DIR/etc/systemd/system"
cat > "$OVERLAY_DIR/etc/systemd/system/macos-tahoe-setup.service" << 'EOF'
[Unit]
Description=macOS Tahoe KVM — First Boot Desktop Icon Setup
After=graphical.target
ConditionPathExists=!/var/lib/macos-tahoe-kvm-installed

[Service]
Type=oneshot
ExecStart=/opt/macos-tahoe-kvm/scripts/install-desktop-launcher.sh
ExecStartPost=/bin/touch /var/lib/macos-tahoe-kvm-installed
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "  Overlay prepared"

# --- Step 6: Build ISO --------------------------------------------------------
echo ""
echo "[6/7] Building ISO..."
echo "  This is where the AnduinOS build system takes over."
echo "  The build injects our overlay into the squashfs."
echo ""

# For now, document the manual steps since AnduinOS build
# requires running on an AMD64 Ubuntu host
cat << 'BUILD_INSTRUCTIONS'
  ┌─────────────────────────────────────────────────────┐
  │  Manual Build Steps (run on AMD64 Ubuntu host):     │
  │                                                     │
  │  1. cd work/AnduinOS                                │
  │  2. Edit src/args.sh (set version)                  │
  │  3. Copy overlay/ into the live filesystem          │
  │  4. Add custom .deb packages to pool                │
  │  5. Run the AnduinOS build:                         │
  │     sudo bash src/build.sh                          │
  │  6. ISO appears in src/dist/                        │
  │                                                     │
  │  Alternatively, remaster an existing AnduinOS ISO:  │
  │  1. Download AnduinOS ISO from anduinos.com         │
  │  2. Extract squashfs                                │
  │  3. Chroot and install custom packages              │
  │  4. Copy overlay files                              │
  │  5. Enable first-boot service                       │
  │  6. Rebuild squashfs and ISO                        │
  └─────────────────────────────────────────────────────┘
BUILD_INSTRUCTIONS

# --- Step 7: Summary ----------------------------------------------------------
echo ""
echo "[7/7] Summary"
echo ""
echo "================================================================"
echo "  Build preparation complete."
echo ""
echo "  Overlay dir:    $OVERLAY_DIR"
echo "  Custom debs:    $WORK_DIR/custom-debs/"
echo "  AnduinOS src:   $WORK_DIR/AnduinOS/"
echo ""
echo "  Next steps:"
echo "    1. Build custom kernel .deb (or convert from Arch PKGBUILD)"
echo "    2. Build Mesa 26.1-dev .deb packages"
echo "    3. Run AnduinOS build on AMD64 Ubuntu host"
echo "    4. Test ISO in QEMU"
echo "    5. Write to USB and boot on Mac Pro 6,1"
echo ""
echo "  IMPORTANT: After install, always POWEROFF (not reboot)"
echo "  when switching kernels. Apple EFI requires cold boot."
echo "================================================================"
