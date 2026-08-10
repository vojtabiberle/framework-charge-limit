# Framework Charge Limit for KDE Plasma 6

A small Plasma 6 widget that switches the battery charge limit of a Framework
Laptop between **80% battery care** and **100% travel mode**. It automatically
selects the standard Linux sysfs backend when available and otherwise falls
back to Framework's official `framework_tool`.

## Screenshots

### Charge controls

![Framework Charge Limit popup](docs/screenshots/charge-controls.png)

### Configurable presets

![Framework Charge Limit settings](docs/screenshots/preset-settings.png)

## Features

- compact panel display showing the current limit or `?`,
- two one-click presets configurable from 0% to 100% in Plasma's widget settings,
- automatic backend detection with the active backend visible in the UI,
- displays any existing 0–100% BIOS/EC or sysfs limit, not only its presets,
- native `charge_control_*_threshold` support with five-point hysteresis,
- `framework_tool` fallback for machines without the kernel interface,
- never mixes the two charge-control APIs,
- reads the actual limit back after changes,
- follows the active Plasma color scheme,
- English source UI with a bundled Czech translation,
- no password prompts after the optional helper installation,
- safe PolicyKit fallback when only the `.plasmoid` UI package is installed.

## Requirements

- a supported Framework Laptop,
- Linux with KDE Plasma 6,
- `framework_tool` from the `framework-system` package for the fallback backend,
- `plasma5support` (for Plasma's executable data engine),
- PolicyKit and `pkexec`.

On Arch Linux and Manjaro:

```bash
sudo pacman -S framework-system plasma5support polkit
```

## Install from source

```bash
git clone git@github.com:vojtabiberle/framework-charge-limit.git
cd framework-charge-limit
./install.sh
```

The installation asks for administrator authentication once. Then add
**Framework Charge Limit** from Plasma's **Add Widgets…** panel.

## Languages

English is the source language and is always available. A Czech translation is
bundled in the package. Translation sources live in `po/`; contributors can
copy `po/cs.po` for a new locale and translate its `msgstr` entries.

After editing a translation, rebuild the binary catalogs with:

```bash
./update-translations.sh
```

Maintainers can refresh the translation template from the QML sources with
`./Messages.sh`. Both commands require GNU gettext.

## Why a privileged helper?

Writing sysfs thresholds and using `framework_tool` both need root access. The
installed helper is owned by root and accepts only `get` or a strictly validated
integer from 0 through 100. It detects the same backend as the widget, uses sysfs whenever
available, and never calls `framework_tool` in that mode. A PolicyKit rule lets
the active local desktop user run this helper without repeated password prompts.
It does not allow arbitrary commands, paths, or out-of-range values.

For the sysfs backend, a limit below 100% uses a start threshold five percentage
points lower than the end threshold. The 100% preset writes 0% and 100%, which
disables the standard EC sustain range. Systems exposing only the end threshold
are also supported.

Review these files before installing:

- `system/framework-charge-limit`
- `system/com.github.frameworkchargelimit.policy`

## Build a distributable package

```bash
./build-package.sh
```

This creates `dist/framework-charge-limit-VERSION.plasmoid`. The `.plasmoid`
contains the UI only. KDE Store packages cannot perform privileged setup on
their own. Reading sysfs remains unprivileged; writes use `pkexec tee`. The
`framework_tool` fallback uses its normal PolicyKit prompt. Running `install.sh`
once adds the restricted helper and removes those repeated prompts.

## Uninstall

```bash
./uninstall.sh
```

Uninstalling intentionally leaves the last charge limit unchanged in firmware.

## Security

The widget never passes unchecked user-supplied text to a shell. Its UI invokes
only the fixed helper path with `get` or a validated integer from 0 through 100.
Sysfs paths are discovered only under `/sys/class/power_supply/BAT*` and
strictly validated by the UI. The helper is installed root-owned and validates
the argument again before writing sysfs or invoking `/usr/bin/framework_tool`
by its absolute path.

## License

MIT
