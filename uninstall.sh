#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

package_id=com.github.vojtabiberle.frameworkchargelimit
legacy_package_id=com.github.frameworkchargelimit.plasmoid

/usr/bin/kpackagetool6 --type Plasma/Applet --remove "$package_id" || true
/usr/bin/kpackagetool6 --type Plasma/Applet --remove "$legacy_package_id" || true

echo "Removing the privileged helper (administrator confirmation required)…"
/usr/bin/pkexec /bin/sh -c \
    '/usr/bin/systemctl disable --now framework-charge-limit-restore.service 2>/dev/null || true; /usr/bin/rm -f /usr/local/libexec/framework-charge-limit /usr/share/polkit-1/actions/com.github.vojtabiberle.frameworkchargelimit.policy /usr/share/polkit-1/actions/com.github.frameworkchargelimit.policy /usr/lib/systemd/system/framework-charge-limit-restore.service /usr/lib/udev/rules.d/90-framework-charge-limit.rules; /usr/bin/rm -rf /var/lib/framework-charge-limit; /usr/bin/systemctl daemon-reload; /usr/bin/udevadm control --reload-rules'

echo "Uninstalled. The current firmware charge limit was left unchanged."
