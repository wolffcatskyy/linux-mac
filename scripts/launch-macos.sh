#!/bin/bash
# linux-mac: Launch macOS Tahoe on Mac Pro 6,1 via KVM
#
# Prerequisites:
#   - linux-macpro61 kernel with KVM support
#   - QEMU 10.0+
#   - OpenCore.qcow2 configured for KVM
#   - macOS disk image
#
# Usage: ./launch-macos.sh [install|run]
#   install — first run with recovery media
#   run     — normal boot (default)

set -euo pipefail

MODE="${1:-run}"
KVM_DIR="${KVM_DIR:-$HOME/kvm}"

QEMU=qemu-system-x86_64
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.fd"
OVMF_VARS="$KVM_DIR/OVMF_VARS.fd"

# Detect CPU cores (leave 2 for host)
TOTAL_CORES=$(nproc)
GUEST_CORES=$(( TOTAL_CORES > 4 ? TOTAL_CORES - 2 : TOTAL_CORES ))

# Detect RAM (give guest half, cap at 32G)
TOTAL_RAM_MB=$(free -m | awk '/Mem:/{print $2}')
GUEST_RAM_MB=$(( TOTAL_RAM_MB / 2 ))
[ "$GUEST_RAM_MB" -gt 32768 ] && GUEST_RAM_MB=32768

echo "=== macOS Tahoe on Mac Pro 6,1 ==="
echo "Mode: $MODE"
echo "Guest CPUs: $GUEST_CORES"
echo "Guest RAM: ${GUEST_RAM_MB}MB"
echo "KVM dir: $KVM_DIR"
echo "===================================="

# Validate files
[ -f "$OVMF_CODE" ] || { echo "Error: OVMF not found at $OVMF_CODE"; exit 1; }
[ -f "$KVM_DIR/OpenCore.qcow2" ] || { echo "Error: OpenCore.qcow2 not found in $KVM_DIR"; exit 1; }
[ -f "$KVM_DIR/macos-tahoe.qcow2" ] || { echo "Error: macos-tahoe.qcow2 not found in $KVM_DIR"; exit 1; }

# Copy OVMF vars if first run
[ -f "$OVMF_VARS" ] || cp /usr/share/edk2/x64/OVMF_VARS.fd "$OVMF_VARS"

# Build QEMU command
QEMU_ARGS=(
    -name "macOS-Tahoe"
    -machine q35,accel=kvm,kernel-irqchip=on
    -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on
    -smp "cores=$GUEST_CORES,threads=1,sockets=1"
    -m "${GUEST_RAM_MB}M"

    # Audio + USB
    -device ich9-intel-hda -device hda-duplex
    -device qemu-xhci,id=xhci
    -device usb-kbd -device usb-tablet

    # UEFI firmware
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$OVMF_VARS"

    # OpenCore bootloader
    -drive "id=OpenCore,if=none,format=qcow2,file=$KVM_DIR/OpenCore.qcow2"
    -device ide-hd,bus=sata.0,drive=OpenCore,bootindex=1

    # macOS disk
    -drive "id=MacHDD,if=none,format=qcow2,file=$KVM_DIR/macos-tahoe.qcow2"
    -device ide-hd,bus=sata.2,drive=MacHDD

    # Network
    -netdev user,id=net0
    -device vmxnet3,netdev=net0

    # Display — QXL + SPICE (Phase 1)
    -vga qxl
    -spice port=5930,disable-ticketing=on
    -device virtio-serial-pci
    -chardev spicevmc,id=spicechannel0,name=vdagent
    -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0

    # Monitor
    -monitor stdio
)

# Add install media if in install mode
if [ "$MODE" = "install" ]; then
    INSTALL_MEDIA="$KVM_DIR/BaseSystem.dmg"
    [ -f "$INSTALL_MEDIA" ] || { echo "Error: BaseSystem.dmg not found in $KVM_DIR"; exit 1; }
    QEMU_ARGS+=(
        -drive "id=InstallMedia,if=none,format=raw,file=$INSTALL_MEDIA"
        -device ide-hd,bus=sata.1,drive=InstallMedia
    )
    echo "Install media: $INSTALL_MEDIA"
fi

echo ""
echo "Connect with: remote-viewer spice://localhost:5930"
echo ""

exec "$QEMU" "${QEMU_ARGS[@]}"
