/*
 * SPDX-FileCopyrightText: 2026 Vojtěch Biberle
 * SPDX-License-Identifier: MIT
 */

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Charge limits")
        icon: "battery"
        source: "configGeneral.qml"
    }
}
