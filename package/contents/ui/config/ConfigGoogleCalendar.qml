import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import ".."
import "../lib"
import "../lib/Requests.js" as Requests

ConfigPage {
	id: page

	function alphaColor(c, a) {
		return Qt.rgba(c.r, c.g, c.b, a)
	}
	readonly property color readablePositiveTextColor: Qt.tint(Kirigami.Theme.textColor, alphaColor(Kirigami.Theme.positiveTextColor, 0.5))
	readonly property color readableNegativeTextColor: Qt.tint(Kirigami.Theme.textColor, alphaColor(Kirigami.Theme.negativeTextColor, 0.5))

	function sortByKey(key, a, b){
		if (typeof a[key] === "string") {
			return a[key].toLowerCase().localeCompare(b[key].toLowerCase())
		} else if (typeof a[key] === "number") {
			return a[key] - b[key]
		} else {
			return 0
		}
	}
	function sortArr(arr, predicate) {
		if (typeof predicate === "string") { // predicate is a key
			predicate = sortByKey.bind(null, predicate)
		}
		return arr.concat().sort(predicate)
	}

	GoogleLoginManager {
		id: googleLoginManager

		onCalendarListChanged: {
			calendarsModel.clear()
			var sortedList = sortArr(calendarList, "summary")
			for (var i = 0; i < sortedList.length; i++) {
				var item = sortedList[i]
				// console.log(JSON.stringify(item))
				var isPrimary = item.primary === true
				var isShown = calendarIdList.indexOf(item.id) >= 0 || (isPrimary && calendarIdList.indexOf('primary') >= 0)
				calendarsModel.append({
					calendarId: item.id,
					name: item.summary,
					description: item.description,
					backgroundColor: item.backgroundColor,
					foregroundColor: item.foregroundColor,
					show: isShown,
					isReadOnly: item.accessRole == "reader",
				})
				// console.log(item.summary, isShown, item.id)
			}
			calendarsModel.calendarsShownChanged()
		}

		onTasklistListChanged: {
			tasklistsModel.clear()
			var sortedList = sortArr(tasklistList, "title")
			for (var i = 0; i < sortedList.length; i++) {
				var item = sortedList[i]
				// console.log(JSON.stringify(item))
				var isShown = tasklistIdList.indexOf(item.id) >= 0
				tasklistsModel.append({
					tasklistId: item.id,
					name: item.title,
					description: '',
					backgroundColor: Kirigami.Theme.highlightColor.toString(),
					foregroundColor: Kirigami.Theme.highlightedTextColor.toString(),
					show: isShown,
					isReadOnly: false,
				})
				// console.log(item.summary, isShown, item.id)
			}
			tasklistsModel.tasklistsShownChanged()
		}

		onError: function(err) { messageWidget.err(err) }
	}


	HeaderText {
		text: i18n("Login")
	}
	MessageWidget {
		id: messageWidget
	}
	ColumnLayout {
		visible: googleLoginManager.isLoggedIn
		QQC2.Label {
			Layout.fillWidth: true
			text: i18n("Currently Synched.")
			color: readablePositiveTextColor
			wrapMode: Text.Wrap
		}
		QQC2.Button {
			text: i18n("Logout")
			onClicked: {
				googleLoginManager.logout()
				calendarsModel.clear()
			}
		}
		MessageWidget {
			visible: googleLoginManager.needsRelog
			text: i18n("Widget has been updated. Please logout and login to Google Calendar again.")
		}
	}
	ColumnLayout {
		visible: !googleLoginManager.isLoggedIn

		QQC2.Label {
			Layout.fillWidth: true
			text: i18n("Google no longer allows widgets to share one login client, so you need your own (free). Follow these steps in order:")
			color: readableNegativeTextColor
			wrapMode: Text.Wrap
		}

		LinkText {
			Layout.fillWidth: true
			text: i18n("1. Open <a href=\"%1\">Google Cloud Console</a> and create a project (or pick an existing one) from the project dropdown at the top.", "https://console.cloud.google.com/projectcreate")
			wrapMode: Text.Wrap
		}
		LinkText {
			Layout.fillWidth: true
			text: i18n("2. Open <a href=\"%1\">Google Auth Platform</a> and click \"Get started\". Choose user type <b>External</b>, fill in an app name and your email, and finish the wizard.", "https://console.cloud.google.com/auth/overview")
			wrapMode: Text.Wrap
		}
		QQC2.Label {
			Layout.fillWidth: true
			text: i18n("3. <b>Important:</b> on the \"Audience\" tab, add your own Google account under \"Test users\" — skip this and login will fail with \"access_denied\". Leave publishing status as \"Testing\"; that's fine for personal use and needs no review from Google.")
			wrapMode: Text.Wrap
			textFormat: Text.RichText
		}
		LinkText {
			Layout.fillWidth: true
			text: i18n("4. Open <a href=\"%1\">API Library</a> and enable the <b>Google Calendar API</b> and <b>Google Tasks API</b> for this project.", "https://console.cloud.google.com/apis/library")
			wrapMode: Text.Wrap
		}
		LinkText {
			Layout.fillWidth: true
			text: i18n("5. Open <a href=\"%1\">Clients</a>, click \"Create Client\", choose application type <b>Desktop app</b>, give it any name, and create it. (Desktop app clients don't need a redirect URI added — Google automatically allows any http://127.0.0.1:port address for this client type.)", "https://console.cloud.google.com/auth/clients")
			wrapMode: Text.Wrap
		}
		QQC2.Label {
			Layout.fillWidth: true
			text: i18n("6. Copy the Client ID and Client Secret it shows you into the two fields below.")
			wrapMode: Text.Wrap
		}
		RowLayout {
			QQC2.Label { text: i18n("Client ID:") }
			ConfigString {
				configKey: 'latestClientId'
				placeholderText: i18n("Eg: 1234567890-abc...xyz.apps.googleusercontent.com")
				Layout.fillWidth: true
			}
		}
		RowLayout {
			QQC2.Label { text: i18n("Client Secret:") }
			ConfigString {
				configKey: 'latestClientSecret'
				placeholderText: i18n("Eg: GOCSPX-...")
				Layout.fillWidth: true
			}
		}

		QQC2.Label {
			Layout.fillWidth: true
			text: i18n("7. Login:")
		}
		RowLayout {
			QQC2.Button {
				text: googleLoginManager.loggingIn ? i18n("Waiting for browser…") : i18n("Login with Google")
				enabled: !googleLoginManager.loggingIn && !!plasmoid.configuration.latestClientId && !!plasmoid.configuration.latestClientSecret
				onClicked: googleLoginManager.login()
			}
			QQC2.BusyIndicator {
				visible: googleLoginManager.loggingIn
				running: visible
				implicitWidth: Kirigami.Units.iconSizes.small
				implicitHeight: implicitWidth
			}
			QQC2.Label {
				visible: !googleLoginManager.loggingIn && (!plasmoid.configuration.latestClientId || !plasmoid.configuration.latestClientSecret)
				text: i18n("(fill in the Client ID and Client Secret above first)")
				color: readableNegativeTextColor
			}
		}
	}

	RowLayout {
		Layout.fillWidth: true
		visible: googleLoginManager.isLoggedIn

		HeaderText {
			text: i18n("Calendars")
		}

		QQC2.Button {
			icon.name: "view-refresh"
			text: i18n("Refresh")
			onClicked: googleLoginManager.updateCalendarList()
		}
	}
	ColumnLayout {
		spacing: Kirigami.Units.smallSpacing * 2
		Layout.fillWidth: true
		visible: googleLoginManager.isLoggedIn

		ListModel {
			id: calendarsModel

			signal calendarsShownChanged()

			onCalendarsShownChanged: {
				var calendarIdList = []
				for (var i = 0; i < calendarsModel.count; i++) {
					var item = calendarsModel.get(i)
					if (item.show) {
						calendarIdList.push(item.calendarId)
					}
				}
				googleLoginManager.calendarIdList = calendarIdList
			}
		}

		ColumnLayout {
			Layout.fillWidth: true

			Repeater {
				model: calendarsModel
				delegate: QQC2.CheckBox {
					id: calendarCheckBox
					text: model.name
					checked: model.show

					contentItem: RowLayout {
						anchors.left: calendarCheckBox.indicator.right
						anchors.leftMargin: Kirigami.Units.smallSpacing
						Rectangle {
							Layout.fillHeight: true
							Layout.preferredWidth: height
							color: model.backgroundColor
						}
						QQC2.Label {
							text: model.name
						}
						LockIcon {
							Layout.fillHeight: true
							Layout.preferredWidth: height
							visible: model.isReadOnly
						}
					}

					onClicked: {
						calendarsModel.setProperty(index, 'show', checked)
						calendarsModel.calendarsShownChanged()
					}
				}
			}
		}
	}

	RowLayout {
		Layout.fillWidth: true
		visible: googleLoginManager.isLoggedIn

		HeaderText {
			text: i18n("Tasks")

			Image {
				source: Qt.resolvedUrl("../../icons/google_tasks_96px.png")
				smooth: true
				anchors.leftMargin: parent.contentWidth + Kirigami.Units.smallSpacing
				anchors.left: parent.left
				anchors.verticalCenter: parent.verticalCenter
				width: Kirigami.Units.iconSizes.smallMedium
				height: Kirigami.Units.iconSizes.smallMedium
			}
		}

		QQC2.Button {
			icon.name: "view-refresh"
			text: i18n("Refresh")
			onClicked: googleLoginManager.updateTasklistList()
		}
	}
	ColumnLayout {
		spacing: Kirigami.Units.smallSpacing * 2
		Layout.fillWidth: true
		visible: googleLoginManager.isLoggedIn

		ListModel {
			id: tasklistsModel

			signal tasklistsShownChanged()

			onTasklistsShownChanged: {
				var tasklistIdList = []
				for (var i = 0; i < tasklistsModel.count; i++) {
					var item = tasklistsModel.get(i)
					if (item.show) {
						tasklistIdList.push(item.tasklistId)
					}
				}
				googleLoginManager.tasklistIdList = tasklistIdList
			}
		}

		ColumnLayout {
			Layout.fillWidth: true

			Repeater {
				model: tasklistsModel
				delegate: QQC2.CheckBox {
					id: tasklistCheckBox
					text: model.name
					checked: model.show

					contentItem: RowLayout {
						anchors.left: tasklistCheckBox.indicator.right
						anchors.leftMargin: Kirigami.Units.smallSpacing
						Rectangle {
							Layout.fillHeight: true
							Layout.preferredWidth: height
							color: model.backgroundColor
						}
						QQC2.Label {
							text: model.name
						}
						LockIcon {
							Layout.fillHeight: true
							Layout.preferredWidth: height
							visible: model.isReadOnly
						}
					}

					onClicked: {
						tasklistsModel.setProperty(index, 'show', checked)
						tasklistsModel.tasklistsShownChanged()
					}
				}
			}
		}
	}

	HeaderText {
		text: i18n("Options")
		visible: googleLoginManager.isLoggedIn
	}

	ColumnLayout {
		Layout.fillWidth: true
		visible: googleLoginManager.isLoggedIn

		ConfigRadioButtonGroup {
			id: googleEventClickAction
			label: i18n("Event Click:")
			configKey: 'googleEventClickAction'
			model: [
				{ value: 'WebEventView', text: i18n("Open Web Event View") },
				{ value: 'WebMonthView', text: i18n("Open Web Month View") },
			]
		}

		ConfigCheckBox {
			configKey: 'googleHideGoalsDesc'
			text: i18n("Hide \"This event was added from Goals in Google Calendar\" description")
		}
	}

	Component.onCompleted: {
		if (googleLoginManager.isLoggedIn) {
			googleLoginManager.calendarListChanged()
			googleLoginManager.tasklistListChanged()
		}
	}
}
