#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

package_id=com.github.frameworkchargelimit.plasmoid

/usr/bin/kpackagetool6 --type Plasma/Applet --remove "$package_id" || true

echo "Removing the privileged helper (administrator confirmation required)…"
/usr/bin/pkexec /bin/sh -c \
    '/usr/bin/rm -f /usr/local/libexec/framework-charge-limit /usr/share/polkit-1/actions/com.github.frameworkchargelimit.policy'

echo "Uninstalled. The current firmware charge limit was left unchanged."
