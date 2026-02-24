#!/usr/bin/env bash
# macOS Tahoe KVM - VNC mode
# Based on documented launch-macos.sh config

if [ "$(cat /sys/module/kvm/parameters/ignore_msrs)" != "Y" ]; then
    sudo sh -c "echo 1 > /sys/module/kvm/parameters/ignore_msrs"
fi

REPO_PATH="."

qemu-system-x86_64 \
    -name "macOS-Tahoe" \
    -machine q35,accel=kvm,kernel-irqchip=on \
    -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on \
    -smp cores=6,threads=1,sockets=1 \
    -m 16G \
    \
    -device ich9-intel-hda -device hda-duplex \
    -device qemu-xhci,id=xhci \
    -device usb-kbd -device usb-tablet \
    \
    -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/OVMF_CODE_4M.fd" \
    -drive if=pflash,format=raw,file="$REPO_PATH/OVMF_VARS-1920x1080.fd" \
    \
    -device ich9-ahci,id=sata \
    -drive id=OpenCore,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2" \
    -device ide-hd,bus=sata.0,drive=OpenCore,bootindex=1 \
    \
    -drive id=InstallMedia,if=none,format=raw,file="$REPO_PATH/BaseSystem.img" \
    -device ide-hd,bus=sata.1,drive=InstallMedia \
    \
    -drive id=MacHDD,if=none,format=qcow2,file="$REPO_PATH/mac_hdd_ng.img" \
    -device ide-hd,bus=sata.2,drive=MacHDD \
    \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device vmxnet3,netdev=net0 \
    \
    -vga qxl \
    -display vnc=0.0.0.0:1 \
    -device virtio-serial-pci \
    \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait \
    -daemonize

echo "VM started. VNC on port 5901"
