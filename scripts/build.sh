#!/bin/bash
# linux-mac: Universal kernel build script
# Usage: ./build.sh <model> [kernel-version]
# Example: ./build.sh MacPro6,1 6.19

set -euo pipefail

MODEL="${1:?Usage: $0 <model> [kernel-version]}"
KVER="${2:-6.19}"
KVER_MAJOR="${KVER%%.*}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/configs/$MODEL"
BUILD_DIR="$REPO_DIR/build"
SRC_DIR="$BUILD_DIR/linux-${KVER}"

# Validate model
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: No config found for model '$MODEL'"
    echo "Available models:"
    ls -1 "$REPO_DIR/configs/"
    exit 1
fi

if [ ! -f "$CONFIG_DIR/config" ]; then
    echo "Error: No kernel config found at $CONFIG_DIR/config"
    exit 1
fi

echo "========================================"
echo " linux-mac kernel builder"
echo " Model:   $MODEL"
echo " Kernel:  $KVER"
echo " Config:  $CONFIG_DIR/config"
echo "========================================"

# Create build directory
mkdir -p "$BUILD_DIR"

# Download kernel source if not present
TARBALL="linux-${KVER}.tar.xz"
if [ ! -f "$BUILD_DIR/$TARBALL" ]; then
    echo "[1/5] Downloading kernel ${KVER}..."
    wget -P "$BUILD_DIR" \
        "https://cdn.kernel.org/pub/linux/kernel/v${KVER_MAJOR}.x/$TARBALL"
else
    echo "[1/5] Kernel source already downloaded."
fi

# Extract
if [ ! -d "$SRC_DIR" ]; then
    echo "[2/5] Extracting..."
    tar -xf "$BUILD_DIR/$TARBALL" -C "$BUILD_DIR"
else
    echo "[2/5] Source already extracted."
fi

# Copy config
echo "[3/5] Applying config for $MODEL..."
cp "$CONFIG_DIR/config" "$SRC_DIR/.config"

# Apply patches
if [ -d "$CONFIG_DIR/patches" ] && [ "$(ls -A "$CONFIG_DIR/patches" 2>/dev/null)" ]; then
    echo "     Applying patches..."
    for patch in "$CONFIG_DIR/patches"/*.patch; do
        echo "     - $(basename "$patch")"
        (cd "$SRC_DIR" && patch -Np1 < "$patch")
    done
else
    echo "     No patches to apply."
fi

# Set localversion
echo "-${MODEL//,/}" | tr '[:upper:]' '[:lower:]' > "$SRC_DIR/localversion"

# Validate config
(cd "$SRC_DIR" && make olddefconfig)

# Build
NPROC=$(nproc)
echo "[4/5] Building with $NPROC jobs..."
echo "     This will take a while. Go get coffee."
(cd "$SRC_DIR" && make -j"$NPROC")

# Report
echo "[5/5] Build complete!"
echo ""
echo "Kernel image: $SRC_DIR/$(cd "$SRC_DIR" && make -s image_name)"
echo "Version:      $(cd "$SRC_DIR" && make -s kernelrelease)"
echo ""
echo "To install manually:"
echo "  sudo cp $SRC_DIR/arch/x86/boot/bzImage /boot/vmlinuz-linux-${MODEL//,/}"
echo "  sudo make -C $SRC_DIR modules_install"
echo ""
echo "Or use the PKGBUILD in packaging/arch/ for a proper package."
echo ""

# Install sysctl config if present
if [ -f "$CONFIG_DIR/sysctl.d/99-macpro.conf" ]; then
    echo "Sysctl config available: $CONFIG_DIR/sysctl.d/99-macpro.conf"
    echo "  sudo cp $CONFIG_DIR/sysctl.d/99-macpro.conf /etc/sysctl.d/"
fi
