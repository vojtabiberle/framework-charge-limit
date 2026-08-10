#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
domain=plasma_applet_com.github.frameworkchargelimit.plasmoid
output_dir=${podir:-"$source_dir/po"}
xgettext_bin=${XGETTEXT:-xgettext}

/usr/bin/mkdir -p "$output_dir"
cd "$source_dir"
"$xgettext_bin" \
    --language=JavaScript \
    --from-code=UTF-8 \
    --keyword=i18n:1 \
    --keyword=i18nc:1c,2 \
    --add-comments=TRANSLATORS \
    --package-name="Framework Charge Limit" \
    --package-version="$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' "$source_dir/package/metadata.json")" \
    --msgid-bugs-address="https://github.com/vojtabiberle/framework-charge-limit/issues" \
    --output="$output_dir/$domain.pot" \
    package/contents/config/config.qml \
    package/contents/ui/configGeneral.qml \
    package/contents/ui/main.qml
