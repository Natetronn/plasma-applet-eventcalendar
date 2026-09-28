import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.workspace.calendar as PlasmaCalendar

import "../lib"
import "../calendars/PlasmaCalendarUtils.js" as PlasmaCalendarUtils

ConfigPage {
	id: page

	// Plasma 6: EventPluginsManager is no longer a singleton, so it must be instantiated.
	PlasmaCalendar.EventPluginsManager {
		id: eventPluginsManager
	}

	HeaderText {
		text: i18n("Event Calendar Plugins")
	}

	ConfigSection {
		QQC2.CheckBox {
			text: i18n("ICalendar (.ics)")
			checked: true
			enabled: false
			visible: plasmoid.configuration.debugging
		}
		QQC2.CheckBox {
			text: i18n("Google Calendar")
			checked: true
			enabled: false
		}
	}


	HeaderText {
		text: i18n("Plasma Calendar Plugins")
	}

	// From digitalclock's configCalendar.qml
	signal configurationChanged()
	ConfigSection {
		Repeater {
			id: calendarPluginsRepeater
			model: eventPluginsManager.model
			delegate: QQC2.CheckBox {
				text: model.display
				checked: model.checked
				onClicked: {
					model.checked = checked // needed for model's setData to be called
					// page.configurationChanged()
					page.saveConfig()
				}
			}
		}
	}
	function saveConfig() {
		plasmoid.configuration.enabledCalendarPlugins = PlasmaCalendarUtils.pluginIdListToFilenameList(eventPluginsManager.enabledPlugins)
	}
	Component.onCompleted: {
		PlasmaCalendarUtils.populateEnabledPluginsByFilename(eventPluginsManager, plasmoid.configuration.enabledCalendarPlugins)
	}

	HeaderText {
		text: i18n("Misc")
	}
	ColumnLayout {

		ConfigSpinBox {
			configKey: 'eventsPollInterval'
			before: i18n("Refresh events every: ")
			suffix: i18nc("Polling interval in minutes", "min")
			minimumValue: 5
			maximumValue: 90
		}
	}

	HeaderText {
		text: i18n("Notifications")
	}

	ConfigSection {
		ConfigNotification {
			label: i18n("Event Reminder")
			notificationEnabledKey: 'eventReminderNotificationEnabled'
			sfxEnabledKey: 'eventReminderSfxEnabled'
			sfxPathKey: 'eventReminderSfxPath'
			sfxPathDefaultValue: '/usr/share/sounds/Oxygen-Im-Nudge.ogg'

			RowLayout {
				spacing: 0
				Item { implicitWidth: parent.parent.indentWidth } // indent
				ConfigSpinBox {
					configKey: 'eventReminderMinutesBefore'
					suffix: i18nc("Polling interval in minutes", "min")
					minimumValue: 1
				}
			}
		}
	}

	ConfigSection {
		ConfigNotification {
			label: i18n("Event Starting")
			notificationEnabledKey: 'eventStartingNotificationEnabled'
			sfxEnabledKey: 'eventStartingSfxEnabled'
			sfxPathKey: 'eventStartingSfxPath'
			sfxPathDefaultValue: '/usr/share/sounds/Oxygen-Im-Nudge.ogg'
		}
	}

}
