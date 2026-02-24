# Mac Pro 6,1 Kernel Config Trim Rules

Reference for what to keep and what to remove when trimming a generic kernel config (e.g., CachyOS base) for Mac Pro 6,1.

## NEVER DISABLE (protected)

### Storage
- ALL NVMe options (aftermarket SSDs via PCIe adapter — Samsung, WD, Sabrent, any brand)
- AHCI (Apple PCIe SSD)
- SCSI core (USB storage, virtio-scsi)
- USB_STORAGE, USB_UAS
- Loop, device-mapper, dm-crypt, LUKS

### GPU
- amdgpu + DRM_AMDGPU_SI (D300/D500/D700 = Tahiti/Pitcairn, GCN 1.0)
- radeon (fallback)
- virtio-gpu (KVM guests)

### Networking
- tg3 + BROADCOM_PHY (BCM57762 dual gigabit)
- Docker: bridge, veth, netfilter, overlay, vxlan, macvlan, ipvlan
- NFS client
- WireGuard

### KVM / Virtualization
- ALL KVM options (Intel VT-x)
- ALL virtio (virtio-gpu, virtio-net, virtio-blk, virtio-scsi, virtio-pci)
- ALL vhost
- ALL VFIO

### Audio
- SND_HDA_INTEL, SND_HDA_CODEC_CIRRUS, SND_HDA_CODEC_HDMI, SND_HDA_CODEC_GENERIC, SND_HDA_CORE

### USB / Thunderbolt
- xHCI, EHCI, OHCI
- USB4 (Thunderbolt 2 — Falcon Ridge + Light Ridge)
- FireWire (Mac Pro has FW800 ports)

### Thermal / Sensors
- applesmc, coretemp

### Bluetooth
- btusb, BT_BCM

### Performance (CachyOS)
- BORE scheduler
- BBR congestion control
- CachyOS tweaks

### Crypto
- AES-NI, GHASH_CLMUL, SHA*, ChaCha20, Poly1305

### Input
- HID core, keyboard, mouse, MAC_EMUMOUSEBTN

### Filesystems
- ext4, btrfs, xfs, fat/vfat, ntfs3, exfat, nfs, overlay, tmpfs, fuse, hfsplus, iso9660

### Platform
- APPLESMC, Apple-specific

## SAFE TO DISABLE

### Other GPUs
- nouveau (Nvidia), i915 (Intel), ast, mgag200, qxl, bochs

### Other NICs
- Intel: e1000/e/igb/igc/ixgbe/ixgbevf/i40e/iavf/ice
- Realtek: r8169, r8152
- Mellanox: mlx4/5
- Chelsio, Marvell (sky2, mvneta), Qualcomm, Cavium, Pensando, Solarflare, Qlogic
- Amazon ENA, Google GVE

### All Wireless Drivers
- iwlwifi, iwlegacy, ath5k/9k/10k/11k/12k, rtw88/89, mt76, rtl8xxxu, brcmfmac, mwifiex
- (BCM4360 uses out-of-tree broadcom-wl-dkms)

### Laptop
- ACPI_BATTERY, ACPI_AC, BACKLIGHT_CLASS_DEVICE
- Touchpad: MOUSE_PS2_SYNAPTICS, MOUSE_PS2_ELANTECH
- Lid switch, ACPI_VIDEO

### Sound Codecs Not Needed
- SND_HDA_CODEC_REALTEK, _SIGMATEL, _VIA, _CONEXANT, _CA0132, _CA0110, _ANALOG
- All SND_SOC_*

### Industrial/IoT
- CAN bus, IIO sensors, W1/1-wire

### InfiniBand/RDMA
- Entire CONFIG_INFINIBAND subsystem

### Wireless WAN
- CONFIG_WWAN

### Media/TV/Radio
- Analog/digital TV, radio tuners, DVB, V4L2 capture devices

### Gaming Input
- JOYSTICK_*, HID_STEAM, gaming controllers

### Unused hwmon
- nct6775, it87, w83627/795, adt7475, lm75/80/85/87, etc.

### Unused Filesystems
- jfs, reiserfs, ocfs2, gfs2, ceph, afs, 9p, orangefs, erofs, f2fs, minix, nilfs2
- adfs, affs, ecryptfs, romfs, cramfs

### Platform Drivers
- Thinkpad, Dell, HP, Toshiba, Samsung laptop, ASUS, MSI, Acer, Lenovo

### Unused Crypto
- Twofish, Serpent, Camellia, CAST5/6, TEA, ARC4, Anubis, Khazad, SEED, SM4

### Other
- Floppy, MTD, ISDN, ATM, amateur radio, DECnet, Appletalk, IRDA, PCMCIA, parallel port

## Rule of Thumb

**If unsure, leave it enabled.** A slightly larger kernel is better than a broken one.
