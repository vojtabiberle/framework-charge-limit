#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
domain=plasma_applet_com.github.vojtabiberle.frameworkchargelimit

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "GNU gettext (msgfmt) is required to build translations." >&2
    exit 69
fi

found=false
for catalog in "$source_dir"/po/*.po; do
    if [ ! -f "$catalog" ]; then
        continue
    fi
    found=true
    locale=$(basename "$catalog" .po)
    output_dir="$source_dir/package/contents/locale/$locale/LC_MESSAGES"
    /usr/bin/mkdir -p "$output_dir"
    msgfmt --check --check-format \
        --output-file="$output_dir/$domain.mo" \
        "$catalog"
done

if [ "$found" = false ]; then
    echo "No translation catalogs found in $source_dir/po." >&2
    exit 66
fi
