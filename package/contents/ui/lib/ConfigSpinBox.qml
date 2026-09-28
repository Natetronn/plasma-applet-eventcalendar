// Version 5

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

RowLayout {
	id: configSpinBox

	property string configKey: ''
	readonly property var configValue: configKey ? plasmoid.configuration[configKey] : 0
	// QQC2.SpinBox only works with integer "value"/"from"/"to", so decimals are handled by
	// scaling to/from an internal integer via decimalFactor.
	// https://doc.qt.io/qt-6/qml-qtquick-controls-spinbox.html#custom-values
	property int decimals: 0
	readonly property real decimalFactor: Math.pow(10, decimals)
	property real maximumValue: 2147483647
	property real minimumValue: 0
	property string prefix: ""
	property real stepSize: 1
	property string suffix: ""
	property real value: configValue
	onValueChanged: serializeTimer.start()

	property alias before: labelBefore.text
	property alias after: labelAfter.text

	QQC2.Label {
		id: labelBefore
		text: ""
		visible: text
	}

	QQC2.SpinBox {
		id: spinBox

		from: Math.round(configSpinBox.minimumValue * configSpinBox.decimalFactor)
		to: Math.round(configSpinBox.maximumValue * configSpinBox.decimalFactor)
		stepSize: Math.max(1, Math.round(configSpinBox.stepSize * configSpinBox.decimalFactor))
		editable: true

		value: Math.round(configSpinBox.value * configSpinBox.decimalFactor)
		onValueModified: configSpinBox.value = value / configSpinBox.decimalFactor

		textFromValue: function(value, locale) {
			return configSpinBox.prefix + Number(value / configSpinBox.decimalFactor).toLocaleString(locale, 'f', configSpinBox.decimals) + configSpinBox.suffix
		}
		valueFromText: function(text, locale) {
			text = text.replace(configSpinBox.prefix, '').replace(configSpinBox.suffix, '')
			return Math.round(Number.fromLocaleString(locale, text) * configSpinBox.decimalFactor)
		}
	}

	QQC2.Label {
		id: labelAfter
		text: ""
		visible: text
	}

	Timer { // throttle
		id: serializeTimer
		interval: 300
		onTriggered: {
			if (configKey) {
				plasmoid.configuration[configKey] = configSpinBox.value
			}
		}
	}
}
