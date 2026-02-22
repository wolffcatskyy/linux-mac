#!/usr/bin/env python3
"""
Audit kernel config: convert all =m to either =y or "not set".
Goal: zero-module workstation kernel for Mac Pro 6,1.

Usage: python3 audit-modules.py <config-file>
Writes output to <config-file>.audited

After applying, run `make olddefconfig` on the build machine to
resolve any dependency issues.
"""

import sys
import re

# ============================================================
# KEEP LIST: =m options that should become =y
# Patterns are matched against the config option name (without CONFIG_ prefix)
# ============================================================

KEEP_PATTERNS = [
    # --- GPU (Mac Pro 6,1 specific) ---
    r'^DRM_RADEON$',            # Legacy driver, keep as fallback
    r'^DRM_RADEON_USERPTR$',
    r'^DRM_QXL$',               # KVM macOS display
    r'^DRM_VKMS$',              # Virtual KMS for testing

    # --- Networking: Docker / containers ---
    r'^BRIDGE$',
    r'^BRIDGE_NETFILTER$',
    r'^VETH$',
    r'^MACVLAN$',
    r'^IPVLAN$',
    r'^VXLAN$',
    r'^DUMMY$',
    r'^VLAN_8021Q',
    r'^BONDING$',
    r'^TUN$',                   # Already =y usually but just in case
    r'^TLS$',

    # --- Netfilter / nftables (Docker needs most of these) ---
    r'^NF_',                    # All netfilter core
    r'^NFT_',                   # All nftables
    r'^NETFILTER_XT_',          # All xtables matches/targets
    r'^IP_NF_',                 # IPv4 netfilter
    r'^IP6_NF_',                # IPv6 netfilter
    r'^IP_SET',                 # IP sets
    r'^IP_VS',                  # IPVS (Docker swarm)
    r'^NETFILTER_NETLINK',      # Netlink interface

    # --- NFS client ---
    r'^NFS_FS$',
    r'^NFS_V[234]',
    r'^LOCKD',
    r'^SUNRPC',
    r'^RPCSEC_GSS',
    r'^FSCACHE',
    r'^CACHEFILES',
    r'^NFS_USE_KERNEL_DNS$',
    r'^NFS_DEBUG$',

    # --- Filesystems ---
    r'^HFSPLUS_FS$',
    r'^HFS_FS$',
    r'^BLK_DEV_DM$',           # Device mapper
    r'^DM_CRYPT$',             # LUKS
    r'^DM_SNAPSHOT$',
    r'^DM_MIRROR$',
    r'^DM_ZERO$',
    r'^DM_THIN_PROVISIONING$',
    r'^DM_LOG_USERSPACE$',
    r'^QUOTA',                 # Disk quotas
    r'^CIFS$',                 # SMB/CIFS client
    r'^SMB_SERVER$',
    r'^ISO9660_FS$',           # CD/DVD ISO
    r'^UDF_FS$',               # UDF
    r'^SQUASHFS',              # Squashfs (common for containers)
    r'^EROFS_FS$',

    # --- Wireless infrastructure (for broadcom-wl DKMS) ---
    r'^CFG80211$',
    r'^MAC80211$',
    r'^LIB80211',

    # --- USB peripherals ---
    r'^SND_USB_AUDIO$',        # USB audio
    r'^USB_RTL8152$',          # USB 2.5GbE adapter
    r'^HID_MULTITOUCH$',
    r'^USB_SERIAL$',           # USB serial adapters
    r'^USB_SERIAL_GENERIC$',
    r'^USB_SERIAL_FTDI_SIO$',
    r'^USB_SERIAL_CH341$',
    r'^USB_SERIAL_CP210X$',
    r'^USB_ACM$',              # USB modem/serial

    # --- FireWire (via Thunderbolt) ---
    r'^FIREWIRE$',
    r'^FIREWIRE_OHCI$',
    r'^FIREWIRE_SBP2$',
    r'^FIREWIRE_NET$',

    # --- Intel platform monitoring ---
    r'^INTEL_POWERCLAMP$',
    r'^INTEL_RAPL',
    r'^INTEL_UNCORE',
    r'^INTEL_CSTATE$',

    # --- Crypto (user API + common algorithms) ---
    r'^CRYPTO_USER_API',
    r'^CRYPTO_USER$',
    r'^CRYPTO_CRC32C',         # Used by ext4, btrfs
    r'^CRYPTO_CRCT10DIF',
    r'^CRYPTO_XXHASH$',
    r'^CRYPTO_BLAKE2B$',
    r'^CRYPTO_LZO$',
    r'^CRYPTO_LZ4',
    r'^CRYPTO_ZSTD$',
    r'^CRYPTO_DEFLATE$',
    r'^CRYPTO_XTS$',           # Common for disk encryption
    r'^CRYPTO_ESSIV$',
    r'^CRYPTO_ECHAINIV$',
    r'^CRYPTO_CBC$',
    r'^CRYPTO_ECB$',
    r'^CRYPTO_CTR$',
    r'^CRYPTO_CMAC$',
    r'^CRYPTO_SEQIV$',
    r'^CRYPTO_AUTHENC$',
    r'^CRYPTO_CHACHA20POLY1305$',
    r'^CRYPTO_GCM$',
    r'^CRYPTO_CCM$',
    r'^CRYPTO_DES$',
    r'^CRYPTO_ARC4$',

    # --- Block layer ---
    r'^BLK_DEV_LOOP$',         # Loop devices
    r'^BLK_DEV_NBD$',          # Network block device

    # --- NVMe (aftermarket adapters extremely common) ---
    r'^NVME_CORE$',
    r'^BLK_DEV_NVME$',
    r'^NVME_KEYRING$',
    r'^NVME_AUTH$',

    # --- General infrastructure ---
    r'^DNOTIFY$',
    r'^DNS_RESOLVER$',
    r'^KEYS_REQUEST_CACHE$',
    r'^ZRAM$',                 # Compressed RAM swap
    r'^NET_SCH_',              # Traffic schedulers
    r'^NET_CLS_',              # Traffic classifiers
    r'^NET_ACT_',              # Traffic actions
    r'^NET_EMATCH',            # Extended matches
    r'^TCF_',                  # TC filters

    # --- ACPI (useful bits) ---
    r'^ACPI_EC_DEBUGFS$',
    r'^ACPI_VIDEO$',
    r'^ACPI_TAD$',

    # --- Virtio (KVM guests) ---
    r'^VIRTIO_BALLOON$',       # Already might be =y
]

# Compile patterns
keep_regexes = [re.compile(p) for p in KEEP_PATTERNS]


def should_keep(option_name):
    """Check if a config option should be kept (=m → =y)."""
    for regex in keep_regexes:
        if regex.search(option_name):
            return True
    return False


def audit_config(input_path):
    output_path = input_path  # overwrite in place

    kept = []
    disabled = []
    unchanged = []

    lines = []
    with open(input_path, 'r') as f:
        original_lines = f.readlines()

    for line in original_lines:
        # Match CONFIG_FOO=m
        m = re.match(r'^(CONFIG_)(\w+)=m\s*$', line)
        if m:
            prefix = m.group(1)
            option = m.group(2)
            if should_keep(option):
                lines.append(f'{prefix}{option}=y\n')
                kept.append(option)
            else:
                lines.append(f'# {prefix}{option} is not set\n')
                disabled.append(option)
        else:
            lines.append(line)
            unchanged.append(line.strip())

    with open(output_path, 'w') as f:
        f.writelines(lines)

    return kept, disabled


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <config-file>")
        sys.exit(1)

    path = sys.argv[1]
    kept, disabled = audit_config(path)

    print(f"Results for {path}:")
    print(f"  Kept as =y:  {len(kept)}")
    print(f"  Disabled:    {len(disabled)}")
    print(f"  Total =m processed: {len(kept) + len(disabled)}")
    print()
    print("Kept options:")
    for opt in sorted(kept):
        print(f"  =y  {opt}")


if __name__ == '__main__':
    main()
