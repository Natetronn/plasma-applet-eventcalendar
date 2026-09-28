import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.Button {
	id: colorTextButton
	padding: Kirigami.Units.smallSpacing // Control.padding is a real (FINAL) property; just set it, don't redeclare it
	implicitWidth: padding + colorTextLabel.implicitWidth + padding
	implicitHeight: padding + colorTextLabel.implicitHeight + padding

	property alias label: colorTextLabel.text

	QQC2.Label {
		id: colorTextLabel
		anchors.centerIn: parent
		color: Kirigami.Theme.textColor
	}
}
