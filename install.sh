#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
package_id=com.github.vojtabiberle.frameworkchargelimit
legacy_package_id=com.github.frameworkchargelimit.plasmoid
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}

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

# Plasma Windowed uses a shared Wayland application ID. StartupWMClass maps its
# window back to this launcher so Task Manager can display our name and icon.
/usr/bin/install -d "$data_home/applications" "$data_home/icons/hicolor/scalable/apps"
/usr/bin/install -m 0644 \
    "$source_dir/desktop/$package_id.desktop" \
    "$data_home/applications/$package_id.desktop"
/usr/bin/install -m 0644 \
    "$source_dir/desktop/$package_id.svg" \
    "$data_home/icons/hicolor/scalable/apps/$package_id.svg"
if [ -x /usr/bin/kbuildsycoca6 ]; then
    /usr/bin/kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "Installed. Add ‘Framework Charge Limit’ from Plasma's Add Widgets panel"
echo "or launch its standalone window from the application menu."

if /usr/bin/kpackagetool6 --type Plasma/Applet --show "$legacy_package_id" >/dev/null 2>&1; then
    echo "An older widget ID is still installed. Replace it in the panel with the new"
    echo "Framework Charge Limit widget; the old package is kept to avoid breaking the panel."
fi
