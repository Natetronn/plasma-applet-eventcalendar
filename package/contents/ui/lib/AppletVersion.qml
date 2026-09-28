import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid

Item {
	implicitWidth: label.implicitWidth
	implicitHeight: label.implicitHeight

	readonly property string version: plasmoid.metaData.version

	QQC2.Label {
		id: label
		text: i18n("<b>Version:</b> %1", version)
	}
}
