/*
 * SPDX-FileCopyrightText: 2026 Vojtěch Biberle
 * SPDX-License-Identifier: MIT
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    // These must be real properties rather than aliases to SpinBox.value.
    // Plasma injects the saved values after constructing this page; aliases
    // made the two mutually constrained spin boxes clamp each other to zero
    // before that happened and did not reliably mark the page as changed.
    property int cfg_careLimit: 80
    property int cfg_travelLimit: 100

    readonly property real thresholdFieldWidth: Kirigami.Units.gridUnit * 6
    readonly property bool limitsValid: cfg_careLimit >= 0
        && cfg_careLimit < cfg_travelLimit
        && cfg_travelLimit <= 100

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Battery-care limit:")

            SpinBox {
                id: careLimitSpinBox
                from: 0
                to: Math.max(0, root.cfg_travelLimit - 1)
                value: root.cfg_careLimit
                stepSize: 1
                editable: true
                Layout.minimumWidth: root.thresholdFieldWidth
                Layout.preferredWidth: root.thresholdFieldWidth

                validator: IntValidator {
                    bottom: careLimitSpinBox.from
                    top: careLimitSpinBox.to
                }

                onValueModified: root.cfg_careLimit = value
            }
            Label {
                text: "%"
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Travel limit:")

            SpinBox {
                id: travelLimitSpinBox
                from: Math.min(100, root.cfg_careLimit + 1)
                to: 100
                value: root.cfg_travelLimit
                stepSize: 1
                editable: true
                Layout.minimumWidth: root.thresholdFieldWidth
                Layout.preferredWidth: root.thresholdFieldWidth

                validator: IntValidator {
                    bottom: travelLimitSpinBox.from
                    top: travelLimitSpinBox.to
                }

                onValueModified: root.cfg_travelLimit = value
            }
            Label {
                text: "%"
            }
        }

        Label {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Enter whole percentages from 0 to 100. The battery-care limit must be lower than the travel limit. Limits below 100% use a start threshold five percentage points lower when the kernel sysfs backend supports it.")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.Wrap
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            visible: !root.limitsValid
            type: Kirigami.MessageType.Error
            text: i18n("Choose two valid limits: battery care must be lower than travel, and both must be between 0% and 100%.")
        }
    }
}
