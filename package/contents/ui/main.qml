/*
 * SPDX-FileCopyrightText: 2026 Vojtěch Biberle
 * SPDX-License-Identifier: MIT
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string helperPath: "/usr/local/libexec/framework-charge-limit"
    property int currentLimit: -1
    readonly property int careLimit: Math.max(0, Math.min(100, Plasmoid.configuration.careLimit))
    readonly property int travelLimit: Math.max(careLimit, Math.min(100, Plasmoid.configuration.travelLimit))
    property string backend: "detecting"
    property string endThresholdPath: ""
    property string startThresholdPath: ""
    // -1: checking, 0: unavailable, 1: installed
    property int helperState: -1
    property bool busy: false
    property string pendingArgument: ""
    property string pendingKind: ""
    property string errorMessage: ""

    Plasmoid.title: i18n("Framework Charge Limit")
    Plasmoid.icon: "battery"
    Plasmoid.status: currentLimit >= 0
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.NeedsAttentionStatus

    toolTipMainText: i18n("Framework Charge Limit")
    toolTipSubText: currentLimit >= 0
        ? i18n("Current limit: %1% · %2", currentLimit, backendDisplayName())
        : i18n("Charge limit is unavailable")

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 12

    function parseLimit(output) {
        const patterns = [
            /maximum\s+([0-9]{1,3})\s*%?/i,
            /charge\s*limit[^0-9]*([0-9]{1,3})\s*%?/i,
            /^\s*([0-9]{1,3})\s*%?\s*$/m
        ];
        for (const pattern of patterns) {
            const match = output.match(pattern);
            if (match) {
                const value = Number(match[1]);
                if (value >= 0 && value <= 100) {
                    return value;
                }
            }
        }
        return -1;
    }

    function runCommand(command, kind, argument) {
        if (busy) {
            return;
        }
        busy = true;
        pendingKind = kind;
        pendingArgument = argument;
        errorMessage = "";
        commandSource.connectSource(command);
    }

    function backendDisplayName() {
        if (backend === "sysfs") {
            return i18n("kernel sysfs");
        }
        if (backend === "framework_tool") {
            return i18n("framework_tool");
        }
        return i18n("detecting…");
    }

    function detectBackend() {
        runCommand(
            "for end in /sys/class/power_supply/BAT*/charge_control_end_threshold; "
                + "do if /usr/bin/test -e \"$end\"; then "
                + "start=${end%end_threshold}start_threshold; "
                + "if /usr/bin/test -e \"$start\"; then "
                + "/usr/bin/printf 'sysfs|%s|%s\\n' \"$end\" \"$start\"; "
                + "else /usr/bin/printf 'sysfs|%s|none\\n' \"$end\"; fi; "
                + "exit 0; fi; done; /usr/bin/printf 'framework_tool\\n'",
            "backend-probe",
            ""
        );
    }

    function probeHelper() {
        runCommand(
            "/usr/bin/test -x " + helperPath,
            "helper-probe",
            ""
        );
    }

    function runBackend(argument) {
        if (helperState < 0) {
            probeHelper();
            return;
        }

        if (helperState === 1) {
            runCommand(
                "/usr/bin/pkexec " + helperPath + " " + argument,
                "helper",
                argument
            );
            return;
        }

        if (backend === "sysfs") {
            if (argument === "get") {
                runCommand(
                    "/usr/bin/cat " + endThresholdPath,
                    "sysfs-read",
                    argument
                );
                return;
            }

            // The paths came from a strict /sys validation in backend-probe,
            // and the only accepted values are fixed below. tee itself, not a
            // privileged shell, is launched through PolicyKit.
            const numericLimit = Number(argument);
            const startValue = numericLimit === 100
                ? "0"
                : String(Math.max(0, numericLimit - 5));
            const writeEnd = "/usr/bin/printf '" + argument
                + "\\n' | /usr/bin/pkexec /usr/bin/tee " + endThresholdPath;
            let command = writeEnd;
            if (startThresholdPath.length > 0) {
                const writeStart = "/usr/bin/printf '" + startValue
                    + "\\n' | /usr/bin/pkexec /usr/bin/tee "
                    + startThresholdPath;
                command = "current=$(/usr/bin/cat " + endThresholdPath + "); "
                    + "if /usr/bin/test " + argument + " -gt \"$current\"; then "
                    + writeEnd + " && " + writeStart + "; else "
                    + writeStart + " && " + writeEnd + "; fi";
            }
            runCommand(command, "sysfs-direct", argument);
            return;
        }

        // KDE Store cannot install privileged system files. Keep the
        // framework_tool backend functional by asking PolicyKit directly.
        const suffix = argument === "get" ? "" : " " + argument;
        runCommand(
            "/usr/bin/pkexec /usr/bin/framework_tool --charge-limit" + suffix,
            "tool-direct",
            argument
        );
    }

    function refresh() {
        if (backend === "detecting") {
            detectBackend();
            return;
        }

        // Reading the standard kernel interface never needs privileges.
        if (backend === "sysfs") {
            runCommand(
                "/usr/bin/cat " + endThresholdPath,
                "sysfs-read",
                "get"
            );
            return;
        }

        runBackend("get");
    }

    function setLimit(limit) {
        if (!Number.isInteger(limit) || limit < 0 || limit > 100) {
            return;
        }
        if (currentLimit === limit) {
            return;
        }
        runBackend(String(limit));
    }

    Plasma5Support.DataSource {
        id: commandSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);

            const standardOutput = String(data["stdout"] || "");
            const standardError = String(data["stderr"] || "");
            const exitCode = Number(data["exit code"] ?? data["exitCode"] ?? 1);
            const completedKind = root.pendingKind;
            const completedArgument = root.pendingArgument;

            root.busy = false;
            root.pendingArgument = "";
            root.pendingKind = "";

            if (completedKind === "backend-probe") {
                const result = standardOutput.trim();
                const sysfsMatch = result.match(
                    /^sysfs\|(\/sys\/class\/power_supply\/BAT[0-9]+\/charge_control_end_threshold)\|(none|\/sys\/class\/power_supply\/BAT[0-9]+\/charge_control_start_threshold)$/
                );

                if (exitCode === 0 && sysfsMatch) {
                    root.backend = "sysfs";
                    root.endThresholdPath = sysfsMatch[1];
                    root.startThresholdPath = sysfsMatch[2] === "none" ? "" : sysfsMatch[2];
                } else if (exitCode === 0 && result === "framework_tool") {
                    root.backend = "framework_tool";
                    root.endThresholdPath = "";
                    root.startThresholdPath = "";
                } else {
                    root.errorMessage = i18n("Could not detect a charge-control backend.");
                    return;
                }

                Qt.callLater(root.probeHelper);
                return;
            }

            if (completedKind === "helper-probe") {
                root.helperState = exitCode === 0 ? 1 : 0;
                if (root.backend === "sysfs" || root.helperState === 1) {
                    Qt.callLater(root.refresh);
                }
                return;
            }

            if (exitCode !== 0) {
                root.errorMessage = standardError.trim()
                    || standardOutput.trim()
                    || i18n("The privileged helper failed.");
                return;
            }

            const parsedLimit = root.parseLimit(standardOutput);
            if (parsedLimit >= 0) {
                root.currentLimit = parsedLimit;
                return;
            }

            // framework_tool versions differ in what the setter prints. A
            // successful direct setter is still authoritative for this run.
            const completedValue = Number(completedArgument);
            if ((completedKind === "tool-direct" || completedKind === "sysfs-direct")
                    && Number.isInteger(completedValue)
                    && completedValue >= 0 && completedValue <= 100) {
                root.currentLimit = completedValue;
                return;
            }

            if (parsedLimit < 0) {
                root.errorMessage = i18n("Could not read the charge limit from %1.", root.backendDisplayName());
                return;
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            if (!root.busy && (root.backend === "sysfs" || root.helperState === 1)) {
                root.refresh();
            }
        }
    }

    onExpandedChanged: function() {
        if (root.expanded && !root.busy
                && (root.backend === "sysfs" || root.helperState === 1)) {
            root.refresh();
        }
    }

    Component.onCompleted: detectBackend()

    compactRepresentation: MouseArea {
        id: compactRoot

        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: Kirigami.Units.gridUnit * 2
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: root.toolTipSubText
        Accessible.role: Accessible.Button
        onClicked: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded
        Keys.onReturnPressed: root.expanded = !root.expanded

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.92
            height: width * 0.72
            radius: Math.max(3, height * 0.22)
            color: root.currentLimit === 100
                || root.currentLimit === root.travelLimit
                ? Kirigami.Theme.positiveTextColor
                : root.currentLimit === root.careLimit
                    ? Kirigami.Theme.highlightColor
                    : root.currentLimit >= 0
                        ? Kirigami.Theme.neutralTextColor
                        : Kirigami.Theme.disabledTextColor

            QQC2.Label {
                anchors.centerIn: parent
                visible: !root.busy
                text: root.currentLimit >= 0 ? String(root.currentLimit) : "?"
                color: "white"
                font.bold: true
                font.pixelSize: Math.max(9, parent.height * (root.currentLimit === 100 ? 0.38 : 0.48))
            }

            QQC2.BusyIndicator {
                anchors.centerIn: parent
                visible: root.busy
                running: visible
                width: parent.height * 0.72
                height: width
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        Layout.preferredWidth: Kirigami.Units.gridUnit * 17
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        text: i18n("Battery charge limit")
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    }
                    PlasmaComponents3.Label {
                        text: root.currentLimit >= 0
                            ? i18n("Currently %1%", root.currentLimit)
                            : i18n("Current value unknown")
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents3.Label {
                        text: i18n("Backend: %1", root.backendDisplayName())
                        color: root.backend === "sysfs"
                            ? Kirigami.Theme.positiveTextColor
                            : Kirigami.Theme.disabledTextColor
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.busy
                    onClicked: root.detectBackend()
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                text: i18n("Battery care — %1%", root.careLimit)
                icon.name: root.currentLimit === root.careLimit ? "checkmark" : "battery-080"
                highlighted: root.currentLimit === root.careLimit
                enabled: !root.busy && root.backend !== "detecting"
                onClicked: root.setLimit(root.careLimit)
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                text: i18n("Travel mode — %1%", root.travelLimit)
                icon.name: root.currentLimit === root.travelLimit ? "checkmark" : "battery-100"
                highlighted: root.currentLimit === root.travelLimit
                enabled: !root.busy && root.backend !== "detecting"
                onClicked: root.setLimit(root.travelLimit)
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.helperState === 0 && root.errorMessage.length === 0
                text: root.backend === "sysfs"
                    ? i18n("Passwordless helper not installed. Sysfs writes will request administrator authentication.")
                    : i18n("Passwordless helper not installed. framework_tool will request administrator authentication.")
                color: Kirigami.Theme.neutralTextColor
                wrapMode: Text.Wrap
            }

            Item {
                Layout.fillHeight: true
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: root.backend === "sysfs"
                    ? i18n("Kernel mode uses five-point hysteresis below 100%. framework_tool is not called.")
                    : i18n("Preset limits can be changed in the widget settings.")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.Wrap
            }
        }
    }
}
