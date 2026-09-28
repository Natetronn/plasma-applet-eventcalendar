import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kitemmodels as KItemModels
import org.kde.plasma.workspace.timezoneselector as Workspace

import ".."
import "../lib"

// Plasma 6 removed org.kde.plasma.private.digitalclock's TimeZoneModel/TimeZoneFilterProxy,
// so this is rebuilt on top of Workspace.TimeZoneUtils.availableTimeZoneIds(), the only public
// P6 API for listing IANA time zone ids.
ColumnLayout { // ConfigPage creates a binding loop when a child uses fillHeight
	id: page

	MessageWidget {
		id: messageWidget
	}

	ListModel { id: timeZoneListModel }

	function splitTimeZoneId(tzid) {
		var parts = tzid.split('/')
		var city = parts[parts.length - 1].replace(/_/g, ' ')
		var region = parts.slice(0, parts.length - 1).join('/').replace(/_/g, ' ')
		return { city: city, region: region }
	}

	function isSelected(tzid) {
		return plasmoid.configuration.selectedTimeZones.indexOf(tzid) >= 0
	}

	function rebuildTimeZoneListModel() {
		timeZoneListModel.clear()
		timeZoneListModel.append({
			tzid: 'Local',
			city: i18n("Local"),
			region: '',
			comment: i18n("System time zone"),
			checked: isSelected('Local'),
		})
		var tzids = Workspace.TimeZoneUtils.availableTimeZoneIds()
		for (var i = 0; i < tzids.length; i++) {
			var tzid = '' + tzids[i]
			var parts = splitTimeZoneId(tzid)
			timeZoneListModel.append({
				tzid: tzid,
				city: parts.city,
				region: parts.region,
				comment: tzid,
				checked: isSelected(tzid),
			})
		}
	}
	Component.onCompleted: rebuildTimeZoneListModel()

	function setChecked(tzid, checked) {
		if (!checked && tzid === 'Local') {
			messageWidget.warn(i18n("Cannot deselect Local time from the tooltip"))
			return
		}
		var selected = plasmoid.configuration.selectedTimeZones.slice()
		var idx = selected.indexOf(tzid)
		if (checked && idx === -1) {
			selected.push(tzid)
		} else if (!checked && idx >= 0) {
			selected.splice(idx, 1)
		}
		plasmoid.configuration.selectedTimeZones = selected

		for (var i = 0; i < timeZoneListModel.count; i++) {
			if (timeZoneListModel.get(i).tzid === tzid) {
				timeZoneListModel.setProperty(i, 'checked', checked)
				break
			}
		}
	}

	KItemModels.KSortFilterProxyModel {
		id: filteredTimeZoneListModel
		sourceModel: timeZoneListModel
		filterRowCallback: function(sourceRow, sourceParent) {
			if (!filter.text) return true
			var item = timeZoneListModel.get(sourceRow)
			var needle = filter.text.toLowerCase()
			return item.city.toLowerCase().indexOf(needle) >= 0
				|| item.region.toLowerCase().indexOf(needle) >= 0
				|| item.tzid.toLowerCase().indexOf(needle) >= 0
		}
	}

	QQC2.TextField {
		id: filter
		Layout.fillWidth: true
		placeholderText: i18n("Search Time Zones")
		onTextChanged: filteredTimeZoneListModel.invalidateFilter()
	}

	QQC2.ScrollView {
		Layout.fillWidth: true
		Layout.fillHeight: true

		ListView {
			id: timeZoneView
			model: filteredTimeZoneListModel
			clip: true

			delegate: QQC2.ItemDelegate {
				width: timeZoneView.width

				contentItem: RowLayout {
					QQC2.CheckBox {
						checked: model.checked
						activeFocusOnTab: false // only let the ListView as a whole get focus
						onToggled: setChecked(model.tzid, checked)
					}
					QQC2.Label {
						text: model.city
						Layout.preferredWidth: 200
					}
					QQC2.Label {
						text: model.region
						Layout.preferredWidth: 200
					}
					QQC2.Label {
						text: model.comment
						Layout.fillWidth: true
						color: Qt.rgba(0, 0, 0, 0.5)
					}
				}
			}
		}
	}


	QQC2.ButtonGroup { id: timezoneDisplayType }
	RowLayout {
		QQC2.Label {
			text: i18n("Display time zone as:")
		}

		QQC2.RadioButton {
			id: timezoneCityRadio
			text: i18n("Time zone city")
			QQC2.ButtonGroup.group: timezoneDisplayType
			checked: !plasmoid.configuration.displayTimezoneAsCode
			onClicked: plasmoid.configuration.displayTimezoneAsCode = false
		}

		QQC2.RadioButton {
			id: timezoneCodeRadio
			text: i18n("Time zone code")
			QQC2.ButtonGroup.group: timezoneDisplayType
			checked: plasmoid.configuration.displayTimezoneAsCode
			onClicked: plasmoid.configuration.displayTimezoneAsCode = true
		}
	}
}
