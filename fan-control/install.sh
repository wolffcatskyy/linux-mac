#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest=${DESTDIR:-}
install -Dm755 "$src/smcfan-ce" "$dest/usr/bin/smcfan-ce"
install -Dm644 "$src/smcfan-ce.service" "$dest/usr/lib/systemd/system/smcfan-ce.service"
install -Dm755 "$src/activate.sh" "$dest/usr/lib/smcfan-ce/activate.sh"
if [[ -n "$dest" ]]; then
    mkdir -p "$dest/etc/systemd/system/multi-user.target.wants"
    ln -sfn /usr/lib/systemd/system/smcfan-ce.service "$dest/etc/systemd/system/multi-user.target.wants/smcfan-ce.service"
else
    bash /usr/lib/smcfan-ce/activate.sh
fi
