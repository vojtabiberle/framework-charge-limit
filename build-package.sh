#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="$source_dir/dist"
version=$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' "$source_dir/package/metadata.json")
archive="$output_dir/framework-charge-limit-$version.plasmoid"

if command -v msgfmt >/dev/null 2>&1; then
    "$source_dir/update-translations.sh"
fi

/usr/bin/mkdir -p "$output_dir"
/usr/bin/rm -f "$archive"

if command -v zip >/dev/null 2>&1; then
    (cd "$source_dir/package" && zip -q -r "$archive" .)
elif command -v bsdtar >/dev/null 2>&1; then
    (cd "$source_dir/package" && bsdtar --format zip -cf "$archive" .)
else
    echo "The zip or bsdtar command is required to build a .plasmoid archive." >&2
    exit 69
fi

echo "$archive"
