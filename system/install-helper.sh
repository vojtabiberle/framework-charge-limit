#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root (use pkexec)." >&2
    exit 77
fi

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

/usr/bin/install -d -m 0755 /usr/local/libexec
/usr/bin/install -o root -g root -m 0755 \
    "$source_dir/framework-charge-limit" \
    /usr/local/libexec/framework-charge-limit
/usr/bin/install -o root -g root -m 0644 \
    "$source_dir/com.github.frameworkchargelimit.policy" \
    /usr/share/polkit-1/actions/com.github.frameworkchargelimit.policy

# Remove the pre-release policy filename if present. The helper path is unchanged.
/usr/bin/rm -f /usr/share/polkit-1/actions/org.framework.charge-limit.policy

echo "Privileged helper installed."
