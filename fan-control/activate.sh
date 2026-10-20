#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Runs in the installation target, never from the image-staging path.
set -euo pipefail

is_live_mac() {
    [[ -d /run/systemd/system ]] &&
        [[ $(cat /sys/class/dmi/id/product_name 2>/dev/null) == 'MacPro6,1' ]] &&
        ! systemd-detect-virt --quiet --chroot &&
        ! systemd-detect-virt --quiet --container
}

activate_main() {
    if is_live_mac; then
        systemctl daemon-reload
        # Keep older enabled units from racing ours on subsequent boots.
        # Starting ours stops their live instances through Conflicts=.
        for unit in macfanctld.service mbpfan.service fancontrol.service macpro-fan-full.service; do
            if systemctl cat "$unit" >/dev/null 2>&1; then
                systemctl disable "$unit"
            fi
        done
        systemctl enable --now smcfan-ce.service
        systemctl is-active --quiet smcfan-ce.service
        echo 'smcFanControl CE started now and enabled for boot.'
    else
        # systemctl enable works offline in a chroot without contacting PID 1.
        systemctl enable smcfan-ce.service
        echo 'smcFanControl CE enabled for target boot; no live hardware takeover in this environment.'
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    activate_main
fi
