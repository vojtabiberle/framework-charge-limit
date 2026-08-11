#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo "This installer must run as root (use pkexec)." >&2
    exit 77
fi

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

/usr/bin/install -d -m 0755 /usr/local/libexec
/usr/bin/install -o root -g root -m 0755 \
    "$source_dir/framework-charge-limit" \
    /usr/local/libexec/framework-charge-limit
/usr/bin/install -o root -g root -m 0644 \
    "$source_dir/com.github.vojtabiberle.frameworkchargelimit.policy" \
    /usr/share/polkit-1/actions/com.github.vojtabiberle.frameworkchargelimit.policy
/usr/bin/install -o root -g root -m 0644 \
    "$source_dir/framework-charge-limit-restore.service" \
    /usr/lib/systemd/system/framework-charge-limit-restore.service
/usr/bin/install -o root -g root -m 0644 \
    "$source_dir/90-framework-charge-limit.rules" \
    /usr/lib/udev/rules.d/90-framework-charge-limit.rules
/usr/bin/install -d -o root -g root -m 0700 /var/lib/framework-charge-limit

# Remove policy filenames used before the stable reverse-domain ID. The helper
# path is unchanged so existing UI instances continue to work during migration.
/usr/bin/rm -f \
    /usr/share/polkit-1/actions/org.framework.charge-limit.policy \
    /usr/share/polkit-1/actions/com.github.frameworkchargelimit.policy

/usr/bin/systemctl daemon-reload
/usr/bin/systemctl enable --now framework-charge-limit-restore.service
/usr/bin/udevadm control --reload-rules

echo "Privileged helper and one-shot restore watcher installed."
