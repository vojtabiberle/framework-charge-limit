#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_id=com.github.frameworkchargelimit.plasmoid

for executable in /usr/bin/pkexec /usr/bin/kpackagetool6; do
    if [ ! -x "$executable" ]; then
        echo "Missing required executable: $executable" >&2
        exit 69
    fi
done

if [ ! -x /usr/bin/framework_tool ]; then
    echo "Note: framework_tool is not installed; only the sysfs backend will be available."
fi

echo "Installing the restricted privileged helper…"
/usr/bin/pkexec "$source_dir/system/install-helper.sh"

if /usr/bin/kpackagetool6 --type Plasma/Applet --show "$package_id" >/dev/null 2>&1; then
    /usr/bin/kpackagetool6 --type Plasma/Applet --upgrade "$source_dir/package"
else
    /usr/bin/kpackagetool6 --type Plasma/Applet --install "$source_dir/package"
fi

echo "Installed. Add ‘Framework Charge Limit’ from Plasma's Add Widgets panel."
