#!/usr/bin/env bash
# =============================================================================
# macOS Tahoe KVM Setup for Mac Pro 6,1
# =============================================================================
# Main launcher script — downloads macOS Tahoe recovery, creates pre-configured
# QEMU virtual machine, and launches the installer.
#
# Target hardware: Mac Pro 6,1 (Late 2013 "Trash Can")
#   - Intel Xeon E5-1620v2 / E5-1650v2 / E5-1680v2 (Ivy Bridge-EP)
#   - Dual AMD FirePro D300/D500/D700
#   - Thunderbolt 2
#
# Usage: ./macos-tahoe-setup.sh [--download-only] [--launch-only] [--passthrough]
# =============================================================================

set -euo pipefail

# -- Paths --------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="${PROJECT_DIR}/vm"
RECOVERY_DIR="${VM_DIR}/recovery"
EFI_DIR="${PROJECT_DIR}/opencore-efi"
OVMF_DIR="${VM_DIR}/ovmf"
LOG_FILE="${PROJECT_DIR}/setup.log"

# -- VM Config (Mac Pro 6,1 optimised) ----------------------------------------
VM_NAME="macOS-Tahoe"
VM_RAM="16G"                  # Mac Pro 6,1 has 12-64GB; 16G is safe default
VM_CPU_SOCKETS=1
VM_CPU_CORES=4                # E5-1620v2=4c, E5-1650v2=6c, E5-1680v2=8c
VM_CPU_THREADS=2              # Hyperthreading enabled
VM_CPU_MODEL="Haswell-noTSX"  # Closest to Ivy Bridge-EP that macOS likes
VM_CPU_FEATURES="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,+abm,+bmi1,+bmi2,check"
VM_DISK_SIZE="128G"           # qcow2 sparse, actual usage ~50-60GB after install
VM_DISPLAY_RES="1920x1080"
VM_MAC_ADDR="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
VM_NET_DEVICE="vmxnet3"       # Better perf than e1000 for Tahoe
VM_DISK_NAME="macOS-Tahoe.qcow2"

# -- macOS Recovery Config -----------------------------------------------------
# Apple's Software Update catalog URLs
APPLE_CATALOG_URL="https://swscan.apple.com/content/catalogs/others/index-15seed-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz"
# Board ID and MLB for Mac Pro 6,1 (needed for macrecovery)
BOARD_ID="Mac-F60DEB81FF30ACF6"
MLB="F5KLA770F9VM"

# -- OVMF firmware URLs --------------------------------------------------------
OVMF_CODE_URL="https://github.com/nicknisi/OVMF/raw/main/OVMF_CODE.fd"
OVMF_VARS_URL="https://github.com/nicknisi/OVMF/raw/main/OVMF_VARS-1920x1080.fd"
# Fallback: build from edk2 or use the ones from ultimate-macOS-KVM
OVMF_CODE_ALT="https://github.com/Coopydood/ultimate-macOS-KVM/raw/main/ovmf/OVMF_CODE.fd"
OVMF_VARS_ALT="https://github.com/Coopydood/ultimate-macOS-KVM/raw/main/ovmf/OVMF_VARS.fd"

# -- Colours -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# =============================================================================
# Logging
# =============================================================================
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
info()  { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "${RED}[ERR ]${NC}  $*" | tee -a "$LOG_FILE"; }
fatal() { err "$*"; exit 1; }

banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            macOS Tahoe KVM — Mac Pro 6,1 Edition            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Pre-configured for Late 2013 Mac Pro (Ivy Bridge-EP)      ║"
    echo "║  Xeon E5 · Dual FirePro · Thunderbolt 2                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# =============================================================================
# Dependency checks
# =============================================================================
check_deps() {
    info "Checking dependencies..."

    local missing=()

    # Required packages
    for cmd in qemu-system-x86_64 qemu-img python3 wget curl openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # KVM support
    if [ ! -e /dev/kvm ]; then
        warn "/dev/kvm not found — KVM acceleration unavailable"
        warn "Performance will be severely degraded without KVM"
        echo -e "  ${YELLOW}Ensure Intel VT-x is enabled in firmware settings${NC}"
        echo -e "  ${YELLOW}Then: sudo modprobe kvm_intel${NC}"
    else
        ok "KVM acceleration available"
    fi

    # IOMMU check (for GPU passthrough)
    if [ -d /sys/kernel/iommu_groups ] && [ "$(ls /sys/kernel/iommu_groups/ 2>/dev/null | wc -l)" -gt 0 ]; then
        ok "IOMMU groups detected (GPU passthrough possible)"
        IOMMU_AVAILABLE=true
    else
        warn "IOMMU not detected — GPU passthrough unavailable"
        warn "Add intel_iommu=on iommu=pt to kernel cmdline for passthrough"
        IOMMU_AVAILABLE=false
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  sudo apt install qemu-system-x86 qemu-utils python3 wget curl openssl"
        echo "  — or —"
        echo "  sudo dnf install qemu-kvm qemu-img python3 wget curl openssl"
        echo "  — or —"
        echo "  sudo pacman -S --needed qemu-full edk2-ovmf python wget curl openssl"
        echo ""
        fatal "Install missing dependencies and re-run."
    fi

    ok "All dependencies satisfied"
}

# =============================================================================
# Detect Mac Pro 6,1 hardware specifics
# =============================================================================
detect_hardware() {
    info "Detecting Mac Pro 6,1 hardware..."

    # CPU detection — adjust core count to match actual hardware
    local cpu_cores
    cpu_cores=$(nproc --all 2>/dev/null || echo 8)
    local allocate_cores=$(( cpu_cores - 2 ))  # Leave 2 for host
    [ "$allocate_cores" -lt 2 ] && allocate_cores=2
    VM_CPU_CORES=$allocate_cores
    ok "CPU: $cpu_cores threads detected, allocating $allocate_cores cores to VM"

    # RAM detection — allocate 75% of total to VM, cap at what's available
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$(( total_ram_kb / 1024 / 1024 ))
    local alloc_ram_gb=$(( total_ram_gb * 3 / 4 ))
    [ "$alloc_ram_gb" -lt 8 ] && alloc_ram_gb=8
    [ "$alloc_ram_gb" -gt 48 ] && alloc_ram_gb=48
    VM_RAM="${alloc_ram_gb}G"
    ok "RAM: ${total_ram_gb}GB total, allocating ${alloc_ram_gb}GB to VM"

    # GPU detection for passthrough
    if lspci 2>/dev/null | grep -qi "FirePro\|Radeon\|AMD.*Display\|ATI"; then
        local gpu_info
        gpu_info=$(lspci | grep -i "VGA\|Display\|3D" | head -2)
        ok "AMD GPU(s) detected:"
        echo "  $gpu_info"
        GPU_DETECTED=true
    else
        warn "No AMD FirePro GPUs detected (expected for Mac Pro 6,1)"
        GPU_DETECTED=false
    fi
}

# =============================================================================
# Download OVMF firmware
# =============================================================================
download_ovmf() {
    mkdir -p "$OVMF_DIR"

    if [ -f "$OVMF_DIR/OVMF_CODE.fd" ] && [ -f "$OVMF_DIR/OVMF_VARS.fd" ]; then
        ok "OVMF firmware already present"
        return 0
    fi

    # Try system-installed OVMF first (no download needed)
    local sys_code="" sys_vars=""
    for code_path in \
        /usr/share/edk2/x64/OVMF_CODE.fd \
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
        /usr/share/OVMF/OVMF_CODE.fd \
        /usr/share/OVMF/OVMF_CODE_4M.fd \
        /usr/share/qemu/OVMF_CODE.fd; do
        if [ -f "$code_path" ]; then
            sys_code="$code_path"
            break
        fi
    done
    for vars_path in \
        /usr/share/edk2/x64/OVMF_VARS.fd \
        /usr/share/edk2-ovmf/x64/OVMF_VARS.fd \
        /usr/share/OVMF/OVMF_VARS.fd \
        /usr/share/OVMF/OVMF_VARS_4M.fd \
        /usr/share/qemu/OVMF_VARS.fd; do
        if [ -f "$vars_path" ]; then
            sys_vars="$vars_path"
            break
        fi
    done

    if [ -n "$sys_code" ] && [ -n "$sys_vars" ]; then
        info "Using system OVMF: $sys_code"
        cp "$sys_code" "$OVMF_DIR/OVMF_CODE.fd"
        cp "$sys_vars" "$OVMF_DIR/OVMF_VARS.fd"
        ok "OVMF firmware copied from system packages"
        return 0
    fi

    info "Downloading OVMF UEFI firmware..."

    wget -q --show-progress -O "$OVMF_DIR/OVMF_CODE.fd" "$OVMF_CODE_URL" 2>&1 || \
        wget -q --show-progress -O "$OVMF_DIR/OVMF_CODE.fd" "$OVMF_CODE_ALT" 2>&1 || \
        fatal "Failed to download OVMF_CODE.fd — install edk2-ovmf (Arch) or ovmf (Debian/Ubuntu)"

    wget -q --show-progress -O "$OVMF_DIR/OVMF_VARS.fd" "$OVMF_VARS_URL" 2>&1 || \
        wget -q --show-progress -O "$OVMF_DIR/OVMF_VARS.fd" "$OVMF_VARS_ALT" 2>&1 || \
        fatal "Failed to download OVMF_VARS.fd — install edk2-ovmf (Arch) or ovmf (Debian/Ubuntu)"

    ok "OVMF firmware downloaded"
}

# =============================================================================
# Download macOS Tahoe recovery image
# =============================================================================
download_recovery() {
    mkdir -p "$RECOVERY_DIR"

    if [ -f "$RECOVERY_DIR/BaseSystem.dmg" ]; then
        ok "macOS recovery image already downloaded"
        echo -e "  ${CYAN}Delete ${RECOVERY_DIR}/BaseSystem.dmg to re-download${NC}"
        return 0
    fi

    info "Downloading macOS Tahoe recovery image from Apple..."
    echo -e "  ${CYAN}This downloads directly from Apple's servers (~700MB)${NC}"
    echo ""

    # Use macrecovery.py from OpenCorePkg
    local macrecovery="${SCRIPT_DIR}/macrecovery.py"
    if [ ! -f "$macrecovery" ]; then
        info "Fetching macrecovery.py from OpenCorePkg..."
        wget -q -O "$macrecovery" \
            "https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/macrecovery.py" || \
            fatal "Failed to download macrecovery.py"
        chmod +x "$macrecovery"
    fi

    # Download Tahoe (macOS 26) recovery
    # Use latest seed catalog for beta/dev builds
    pushd "$RECOVERY_DIR" > /dev/null
    python3 "$macrecovery" \
        -b "$BOARD_ID" \
        -m "$MLB" \
        -os latest \
        download || {
            warn "macrecovery download failed, trying alternative method..."
            # Fallback: try with default board ID
            python3 "$macrecovery" \
                -os latest \
                download || fatal "Failed to download macOS recovery image"
        }
    popd > /dev/null

    if [ -f "$RECOVERY_DIR/BaseSystem.dmg" ]; then
        local size
        size=$(du -h "$RECOVERY_DIR/BaseSystem.dmg" | cut -f1)
        ok "macOS recovery downloaded (${size})"
    else
        # Some versions download as RecoveryImage.dmg
        if [ -f "$RECOVERY_DIR/RecoveryImage.dmg" ]; then
            mv "$RECOVERY_DIR/RecoveryImage.dmg" "$RECOVERY_DIR/BaseSystem.dmg"
            ok "macOS recovery downloaded (renamed RecoveryImage → BaseSystem)"
        else
            fatal "Recovery image not found after download"
        fi
    fi
}

# =============================================================================
# Create virtual disk
# =============================================================================
create_disk() {
    local disk_path="${VM_DIR}/${VM_DISK_NAME}"

    if [ -f "$disk_path" ]; then
        ok "Virtual disk already exists: ${VM_DISK_NAME}"
        echo -e "  ${CYAN}Delete ${disk_path} to recreate${NC}"
        return 0
    fi

    info "Creating ${VM_DISK_SIZE} virtual disk (qcow2 sparse)..."
    mkdir -p "$VM_DIR"
    qemu-img create -f qcow2 "$disk_path" "$VM_DISK_SIZE"
    ok "Virtual disk created: ${VM_DISK_NAME} (${VM_DISK_SIZE} sparse)"
}

# =============================================================================
# Generate QEMU launch script
# =============================================================================
generate_launch_script() {
    local launch_script="${PROJECT_DIR}/launch-macos-tahoe.sh"
    local disk_path="${VM_DIR}/${VM_DISK_NAME}"

    info "Generating QEMU launch script..."

    # Determine OpenCore image path
    local opencore_img="${EFI_DIR}/OpenCore.qcow2"
    if [ ! -f "$opencore_img" ]; then
        warn "OpenCore.qcow2 not found at ${opencore_img}"
        warn "You need to provide an OpenCore EFI image for macOS boot"
        warn "See: https://github.com/Coopydood/ultimate-macOS-KVM/wiki"
        err "CRITICAL: CryptexFixup.kext MUST be included in your OpenCore EFI"
        err "  Without it, macOS Tahoe will NOT boot in a KVM virtual machine."
        err "  Get it from: https://github.com/acidanthera/CryptexFixup/releases"
        opencore_img="OPENCORE_IMAGE_PATH_HERE"
    fi

    cat > "$launch_script" << 'QEMU_SCRIPT_HEADER'
#!/usr/bin/env bash
# =============================================================================
# macOS Tahoe KVM Launch Script — Mac Pro 6,1
# Auto-generated — edit VM_* variables below to customise
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QEMU_SCRIPT_HEADER

    cat >> "$launch_script" << QEMU_SCRIPT_VARS
# -- VM Configuration ----------------------------------------------------------
VM_NAME="${VM_NAME}"
VM_RAM="${VM_RAM}"
VM_CPU_SOCKETS=${VM_CPU_SOCKETS}
VM_CPU_CORES=${VM_CPU_CORES}
VM_CPU_THREADS=${VM_CPU_THREADS}
VM_CPU_MODEL="${VM_CPU_MODEL}"
VM_CPU_FEATURES="${VM_CPU_FEATURES}"
VM_MAC_ADDR="${VM_MAC_ADDR}"
VM_NET_DEVICE="${VM_NET_DEVICE}"

# -- Paths ---------------------------------------------------------------------
VM_DIR="\${SCRIPT_DIR}/vm"
OVMF_CODE="\${VM_DIR}/ovmf/OVMF_CODE.fd"
OVMF_VARS="\${VM_DIR}/ovmf/OVMF_VARS.fd"
OPENCORE_IMG="${opencore_img}"
DISK_IMG="\${VM_DIR}/${VM_DISK_NAME}"
RECOVERY_IMG="\${VM_DIR}/recovery/BaseSystem.dmg"

QEMU_SCRIPT_VARS

    cat >> "$launch_script" << 'QEMU_SCRIPT_BODY'
# -- Pre-flight checks ---------------------------------------------------------
if [ ! -e /dev/kvm ]; then
    echo "[WARN] /dev/kvm not found — running without KVM (very slow!)"
    KVM_FLAG=""
else
    KVM_FLAG="-enable-kvm"
fi

for f in "$OVMF_CODE" "$OVMF_VARS" "$DISK_IMG"; do
    [ -f "$f" ] || { echo "[ERR] Missing: $f"; exit 1; }
done

# Include recovery image on first boot (remove after install)
RECOVERY_ARGS=""
if [ -f "$RECOVERY_IMG" ]; then
    echo "[INFO] Recovery image found — including for installation"
    RECOVERY_ARGS="-device ide-hd,bus=sata.3,drive=recovery
        -drive id=recovery,if=none,format=raw,file=${RECOVERY_IMG},readonly=on"
fi

# Include OpenCore if available
OPENCORE_ARGS=""
if [ -f "$OPENCORE_IMG" ]; then
    echo "[INFO] OpenCore image found — booting with OpenCore EFI"
    OPENCORE_ARGS="-device ide-hd,bus=sata.2,drive=opencore
        -drive id=opencore,if=none,format=qcow2,file=${OPENCORE_IMG}"
fi

# -- GPU Passthrough (optional) -----------------------------------------------
# Uncomment and set your IOMMU group PCI addresses to enable GPU passthrough.
# Find your GPU PCI addresses with: lspci -nn | grep -i "amd\|ati\|radeon\|firepro"
# Find IOMMU groups with the find-iommu-groups.sh helper script.
#
# GPU_PASSTHROUGH_ARGS="
#   -device vfio-pci,host=XX:XX.0,multifunction=on
#   -device vfio-pci,host=XX:XX.1
# "
GPU_PASSTHROUGH_ARGS=""

# =============================================================================
# QEMU Launch
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Launching macOS Tahoe VM — Mac Pro 6,1             ║"
echo "║  RAM: ${VM_RAM} | CPU: ${VM_CPU_CORES}c/${VM_CPU_THREADS}t | Disk: ${DISK_IMG##*/}  "
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

exec qemu-system-x86_64 \
    $KVM_FLAG \
    -name "$VM_NAME" \
    \
    -machine q35,accel=kvm \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.disable_s4=1 \
    \
    -cpu "$VM_CPU_MODEL","$VM_CPU_FEATURES" \
    -smp sockets=$VM_CPU_SOCKETS,cores=$VM_CPU_CORES,threads=$VM_CPU_THREADS \
    -m "$VM_RAM" \
    \
    -device qemu-xhci,id=xhci \
    -device usb-kbd \
    -device usb-tablet \
    \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    \
    -device ich9-ahci,id=sata \
    -device ide-hd,bus=sata.0,drive=disk0,bootindex=1 \
    -drive id=disk0,if=none,format=qcow2,file="$DISK_IMG",discard=unmap,detect-zeroes=unmap \
    \
    $OPENCORE_ARGS \
    $RECOVERY_ARGS \
    \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device "$VM_NET_DEVICE",netdev=net0,mac="$VM_MAC_ADDR" \
    \
    -device ich9-intel-hda \
    -device hda-duplex \
    \
    -vga std \
    -display gtk,show-cursor=on \
    -usb \
    \
    -device virtio-rng-pci \
    \
    $GPU_PASSTHROUGH_ARGS \
    \
    -monitor stdio
QEMU_SCRIPT_BODY

    chmod +x "$launch_script"
    ok "Launch script generated: launch-macos-tahoe.sh"
}

# =============================================================================
# Generate IOMMU group finder helper
# =============================================================================
generate_iommu_helper() {
    local helper="${SCRIPT_DIR}/find-iommu-groups.sh"

    cat > "$helper" << 'EOF'
#!/usr/bin/env bash
# List IOMMU groups and their devices — useful for GPU passthrough setup
echo "IOMMU Groups and Devices:"
echo "========================="
for g in /sys/kernel/iommu_groups/*/devices/*; do
    group=$(echo "$g" | grep -oP 'iommu_groups/\K[0-9]+')
    device=$(basename "$g")
    desc=$(lspci -nns "$device" 2>/dev/null || echo "unknown")
    printf "Group %2s: %s → %s\n" "$group" "$device" "$desc"
done | sort -t: -k1 -n
echo ""
echo "For GPU passthrough, find your FirePro D-series GPU and its audio device."
echo "They should be in the same IOMMU group."
echo "Add their PCI addresses to GPU_PASSTHROUGH_ARGS in launch-macos-tahoe.sh"
EOF
    chmod +x "$helper"
    ok "IOMMU helper script created: find-iommu-groups.sh"
}

# =============================================================================
# Generate VFIO bind helper
# =============================================================================
generate_vfio_bind() {
    local helper="${SCRIPT_DIR}/bind-vfio.sh"

    cat > "$helper" << 'VFIO_EOF'
#!/usr/bin/env bash
# =============================================================================
# VFIO-PCI GPU Bind Script for Mac Pro 6,1 FirePro GPUs
# Run this BEFORE launching the VM to unbind GPUs from host and bind to vfio-pci
# Usage: sudo ./bind-vfio.sh <PCI_ADDR_1> [PCI_ADDR_2] ...
# Example: sudo ./bind-vfio.sh 03:00.0 03:00.1 04:00.0 04:00.1
# =============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root: sudo $0 $*"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: sudo $0 <PCI_ADDR> [PCI_ADDR ...]"
    echo "Find addresses with: lspci -nn | grep -i firepro"
    exit 1
fi

# Load vfio modules
modprobe vfio-pci

for addr in "$@"; do
    full_addr="0000:${addr}"
    vendor_device=$(cat "/sys/bus/pci/devices/${full_addr}/vendor" 2>/dev/null || true)
    device_id=$(cat "/sys/bus/pci/devices/${full_addr}/device" 2>/dev/null || true)

    if [ -z "$vendor_device" ]; then
        echo "[ERR] Device ${addr} not found"
        continue
    fi

    echo "[INFO] Unbinding ${addr} from current driver..."
    echo "$full_addr" > "/sys/bus/pci/devices/${full_addr}/driver/unbind" 2>/dev/null || true

    echo "[INFO] Binding ${addr} to vfio-pci..."
    echo "${vendor_device} ${device_id}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true

    echo "[ OK ] ${addr} bound to vfio-pci"
done

echo ""
echo "GPU(s) bound to vfio-pci. You can now launch the VM with passthrough."
VFIO_EOF
    chmod +x "$helper"
    ok "VFIO bind script created: bind-vfio.sh"
}

# =============================================================================
# Main
# =============================================================================
main() {
    banner
    mkdir -p "$VM_DIR"
    : > "$LOG_FILE"

    # Parse args
    DOWNLOAD_ONLY=false
    LAUNCH_ONLY=false
    PASSTHROUGH=false
    for arg in "$@"; do
        case "$arg" in
            --download-only) DOWNLOAD_ONLY=true ;;
            --launch-only)   LAUNCH_ONLY=true ;;
            --passthrough)   PASSTHROUGH=true ;;
            --help|-h)
                echo "Usage: $0 [--download-only] [--launch-only] [--passthrough]"
                echo ""
                echo "  --download-only   Only download recovery image and OVMF, don't launch"
                echo "  --launch-only     Skip downloads, just launch the VM"
                echo "  --passthrough     Enable GPU passthrough prompts"
                exit 0
                ;;
        esac
    done

    if ! $LAUNCH_ONLY; then
        echo -e "${BOLD}Phase 1: System Check${NC}"
        echo "─────────────────────────────────────────"
        check_deps
        detect_hardware
        echo ""

        echo -e "${BOLD}Phase 2: Download Components${NC}"
        echo "─────────────────────────────────────────"
        download_ovmf
        download_recovery
        echo ""

        echo -e "${BOLD}Phase 3: Configure Virtual Machine${NC}"
        echo "─────────────────────────────────────────"
        create_disk
        generate_launch_script
        generate_iommu_helper
        generate_vfio_bind
        echo ""
    fi

    if $DOWNLOAD_ONLY; then
        ok "Download complete. Run again without --download-only to configure and launch."
        exit 0
    fi

    # Summary
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    echo "  VM Config:"
    echo "    CPU:    ${VM_CPU_MODEL} (${VM_CPU_CORES}c/${VM_CPU_THREADS}t)"
    echo "    RAM:    ${VM_RAM}"
    echo "    Disk:   ${VM_DISK_SIZE} (qcow2 sparse)"
    echo "    Net:    ${VM_NET_DEVICE} (${VM_MAC_ADDR})"
    echo ""
    echo "  Files:"
    echo "    Launch script:  ${PROJECT_DIR}/launch-macos-tahoe.sh"
    echo "    Virtual disk:   ${VM_DIR}/${VM_DISK_NAME}"
    echo "    Recovery image: ${RECOVERY_DIR}/BaseSystem.dmg"
    echo ""

    if [ "${OPENCORE_IMG:-}" = "OPENCORE_IMAGE_PATH_HERE" ] || [ ! -f "${EFI_DIR}/OpenCore.qcow2" ]; then
        echo -e "  ${YELLOW}${BOLD}⚠  OpenCore EFI image needed${NC}"
        echo -e "  ${YELLOW}   Download from: https://github.com/acidanthera/OpenCorePkg/releases${NC}"
        echo -e "  ${YELLOW}   Place at: ${EFI_DIR}/OpenCore.qcow2${NC}"
        echo -e "  ${YELLOW}   Or use ultimate-macOS-KVM's OpenCore Configuration Assistant${NC}"
        echo ""
        echo -e "  ${RED}${BOLD}CRITICAL: CryptexFixup.kext is REQUIRED in your OpenCore EFI${NC}"
        echo -e "  ${RED}   Without it, macOS Tahoe will NOT boot in a KVM virtual machine.${NC}"
        echo -e "  ${RED}   Download from: https://github.com/acidanthera/CryptexFixup/releases${NC}"
        echo -e "  ${RED}   Add to EFI/OC/Kexts/ and enable in config.plist -> Kernel -> Add${NC}"
        echo ""
    fi

    echo -e "  ${CYAN}To launch:${NC}"
    echo "    ./launch-macos-tahoe.sh"
    echo ""
    echo -e "  ${CYAN}For GPU passthrough:${NC}"
    echo "    1. sudo ./scripts/find-iommu-groups.sh"
    echo "    2. sudo ./scripts/bind-vfio.sh <GPU_PCI_ADDR>"
    echo "    3. Edit GPU_PASSTHROUGH_ARGS in launch-macos-tahoe.sh"
    echo ""

    # Offer to launch now
    read -rp "Launch macOS Tahoe VM now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        exec "${PROJECT_DIR}/launch-macos-tahoe.sh"
    fi
}

main "$@"
