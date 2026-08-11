#!/bin/sh
# SPDX-FileCopyrightText: 2026 Vojtěch Biberle
# SPDX-License-Identifier: MIT

set -eu

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary_dir=$(/usr/bin/mktemp -d)
trap '/usr/bin/rm -rf "$temporary_dir"' EXIT HUP INT TERM

helper=$temporary_dir/framework-charge-limit
tool=$temporary_dir/framework_tool
tool_limit=$temporary_dir/tool-limit
power_root=$temporary_dir/power_supply
state_dir=$temporary_dir/state

/usr/bin/cp "$source_dir/system/framework-charge-limit" "$helper"
# Match the literal variable reference in the copied production script.
# shellcheck disable=SC2016
/usr/bin/sed -i \
    -e "s|FRAMEWORK_TOOL=/usr/bin/framework_tool|FRAMEWORK_TOOL=$tool|" \
    -e "s|POWER_SUPPLY_ROOT=/sys/class/power_supply|POWER_SUPPLY_ROOT=$power_root|" \
    -e "s|STATE_DIR=/var/lib/framework-charge-limit|STATE_DIR=$state_dir|" \
    -e 's|/usr/bin/install -d -o root -g root -m 0700 "$STATE_DIR"|/usr/bin/mkdir -p "$STATE_DIR"|' \
    -e '/^require_root() {$/,/^}$/c\
require_root() {\
    :\
}' \
    "$helper"

printf '80\n' > "$tool_limit"
/usr/bin/mkdir -p "$power_root/AC" "$power_root/USB" "$power_root/BAT1"
printf 'Mains\n' > "$power_root/AC/type"
printf '1\n' > "$power_root/AC/online"
printf 'USB\n' > "$power_root/USB/type"
printf '0\n' > "$power_root/USB/online"
printf 'Battery\n' > "$power_root/BAT1/type"

cat > "$tool" <<'TOOL'
#!/bin/sh
set -eu
state_file=${0%/*}/tool-limit
if [ "${1-}" != "--charge-limit" ]; then
    exit 64
fi
if [ "$#" -eq 2 ]; then
    printf '%s\n' "$2" > "$state_file"
fi
value=$(cat "$state_file")
printf 'Minimum 0%%, Maximum %s%%\n' "$value"
TOOL
/usr/bin/chmod 0755 "$helper" "$tool"

assert_equal() {
    expected=$1
    actual=$2
    if [ "$actual" != "$expected" ]; then
        printf 'Expected "%s", got "%s"\n' "$expected" "$actual" >&2
        exit 1
    fi
}

assert_equal inactive "$("$helper" status)"
"$helper" once 65 >/dev/null
assert_equal 100 "$(cat "$tool_limit")"
assert_equal 'armed 65' "$("$helper" status)"

"$helper" 80 >/dev/null
assert_equal 80 "$(cat "$tool_limit")"
assert_equal inactive "$("$helper" status)"

"$helper" once 65 >/dev/null
printf '1\n' > "$power_root/USB/online"
printf '0\n' > "$power_root/AC/online"
assert_equal 'armed 65' "$("$helper" restore)"
assert_equal 100 "$(cat "$tool_limit")"

printf '0\n' > "$power_root/USB/online"
"$helper" restore >/dev/null
assert_equal 65 "$(cat "$tool_limit")"
assert_equal inactive "$("$helper" status)"

if "$helper" once 80 >/dev/null 2>&1; then
    echo "One-shot mode unexpectedly succeeded without external power." >&2
    exit 1
else
    assert_equal 75 "$?"
fi

printf '80\n' > "$power_root/BAT1/charge_control_end_threshold"
printf '75\n' > "$power_root/BAT1/charge_control_start_threshold"
"$helper" 65 >/dev/null
assert_equal 65 "$(cat "$power_root/BAT1/charge_control_end_threshold")"
assert_equal 60 "$(cat "$power_root/BAT1/charge_control_start_threshold")"
"$helper" 100 >/dev/null
assert_equal 100 "$(cat "$power_root/BAT1/charge_control_end_threshold")"
assert_equal 0 "$(cat "$power_root/BAT1/charge_control_start_threshold")"

echo "Helper tests passed."
