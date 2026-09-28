// Version 3

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import ".."

QQC2.CheckBox {
	id: configCheckBox

	property string configKey: ''
	checked: plasmoid.configuration[configKey]
	onClicked: plasmoid.configuration[configKey] = !plasmoid.configuration[configKey]
}
