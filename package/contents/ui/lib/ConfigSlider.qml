// Version 3

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

RowLayout {
	id: configSlider

	property string configKey: ''
	property alias maximumValue: slider.to
	property alias minimumValue: slider.from
	property alias stepSize: slider.stepSize
	property alias updateValueWhileDragging: slider.live
	property alias value: slider.value

	property alias before: labelBefore.text
	property alias after: labelAfter.text

	Layout.fillWidth: true

	QQC2.Label {
		id: labelBefore
		text: ""
		visible: text
	}

	QQC2.Slider {
		id: slider
		Layout.fillWidth: configSlider.Layout.fillWidth

		value: plasmoid.configuration[configKey]
		// onValueChanged: plasmoid.configuration[configKey] = value
		onValueChanged: serializeTimer.start()
		to: 2147483647
	}

	QQC2.Label {
		id: labelAfter
		text: ""
		visible: text
	}

	Timer { // throttle
		id: serializeTimer
		interval: 300
		onTriggered: plasmoid.configuration[configKey] = value
	}
}
