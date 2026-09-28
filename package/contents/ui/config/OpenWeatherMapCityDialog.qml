import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

import ".."
import "../lib"
import "../lib/Requests.js" as Requests

QQC2.Dialog {
	id: chooseCityDialog
	title: i18n("Select city")
	standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

	width: 500
	height: 600
	property bool loadingCityList: false

	Logger {
		id: logger
		showDebug: plasmoid.configuration.debugging
	}

	ListModel { id: cityListModel }
	KItemModels.KSortFilterProxyModel {
		id: filteredCityListModel
		// sourceModel: cityListModel // Link after populating cityListModel so the UI doesn't freeze.
		filterRoleName: 'name'
		sortRoleName: 'name'
		filterCaseSensitivity: Qt.CaseInsensitive
		sortCaseSensitivity: Qt.CaseInsensitive
	}

	property string selectedCityId: ''

	Timer {
		id: debouceApplyFilter
		interval: 1000
		onTriggered: chooseCityDialog.applyCityListSearch()
	}

	contentItem: ColumnLayout {
		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://openweathermap.org/find")
		}
		QQC2.TextField {
			id: cityNameInput
			Layout.fillWidth: true
			text: ''
			placeholderText: i18n("Search")
			onTextChanged: {
				filteredCityListModel.filterString = text
				debouceApplyFilter.restart()
			}
		}

		RowLayout {
			Layout.fillWidth: true
			QQC2.Label { text: i18n("Name"); Layout.preferredWidth: 240; font.bold: true }
			QQC2.Label { text: i18n("Id"); Layout.preferredWidth: 100; font.bold: true }
			QQC2.Label { text: i18n("City Webpage"); Layout.fillWidth: true; font.bold: true }
		}

		QQC2.ScrollView {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.minimumHeight: 200

			ListView {
				id: cityListView
				model: filteredCityListModel
				currentIndex: -1
				clip: true

				delegate: QQC2.ItemDelegate {
					width: cityListView.width
					highlighted: ListView.isCurrentItem
					onClicked: {
						cityListView.currentIndex = index
						chooseCityDialog.selectedCityId = model.id
					}

					contentItem: RowLayout {
						QQC2.Label { text: model.name; Layout.preferredWidth: 240 }
						QQC2.Label { text: model.id; Layout.preferredWidth: 100 }
						LinkText {
							Layout.fillWidth: true
							text: '<a href="https://openweathermap.org/city/' + model.id + '">' + i18n("Open Link") + '</a>'
							linkColor: (index === cityListView.currentIndex) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.linkColor
						}
					}
				}
			}

			QQC2.BusyIndicator {
				anchors.centerIn: parent
				running: visible
				visible: chooseCityDialog.loadingCityList
			}
		}
	}

	function clearCityList() {
		// clear list so that each append() doesn't rebuild the UI
		filteredCityListModel.sourceModel = null
		cityListModel.clear()
	}

	function parseCityList(data) {
		for (var i = 0; i < data.list.length; i++) {
			var item = data.list[i]
			var city = {
				id: item.id,
				name: item.name + ', ' + item.sys.country,
			}
			cityListModel.append(city)
		}
	}

	function applyCityListSearch() {
		searchCityList(cityNameInput.text)
	}

	function searchCityList(q) {
		logger.debug('searchCityList', q)
		clearCityList()
		if (q) {
			chooseCityDialog.loadingCityList = true
			fetchCityList({
				appId: plasmoid.configuration.openWeatherMapAppId,
				q: q,
			}, function(err, data, xhr) {
				if (err) return console.log('searchCityList.err', err, xhr && xhr.status, data)
				logger.debug('searchCityList.response')
				logger.debugJSON('searchCityList.response', data)

				parseCityList(data)

				// link after populating so that each append() doesn't attempt to rebuild the UI.
				filteredCityListModel.sourceModel = cityListModel

				chooseCityDialog.loadingCityList = false
			})
		}
	}

	function fetchCityList(args, callback) {
		if (!args.appId) return callback('OpenWeatherMap AppId not set')

		var url = 'https://api.openweathermap.org/data/2.5/'
		url += 'find?q=' + encodeURIComponent(args.q)
		url += '&type=like'
		url += '&sort=population'
		url += '&cnt=30'
		url += '&appid=' + args.appId
		Requests.getJSON(url, callback)
	}
}
