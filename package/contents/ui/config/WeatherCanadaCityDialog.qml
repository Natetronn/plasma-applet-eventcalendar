import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

import "../lib/Requests.js" as Requests
import ".."
import "../weather/WeatherCanada.js" as WeatherCanada

QQC2.Dialog {
	id: chooseCityDialog
	title: i18n("Select city")
	standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

	width: 500
	height: 600
	property bool loadingCityList: false
	property bool cityListLoaded: false

	ListModel { id: emptyListModel }
	ListModel { id: cityListModel }
	KItemModels.KSortFilterProxyModel {
		id: filteredCityListModel
		// sourceModel: cityListModel // Link after populating cityListModel so the UI doesn't freeze.
		sourceModel: emptyListModel
		filterRoleName: 'name'
		sortRoleName: 'name'
		filterCaseSensitivity: Qt.CaseInsensitive
		sortCaseSensitivity: Qt.CaseInsensitive
	}

	property string selectedCityId: ''

	Timer {
		id: debouceApplyFilter
		interval: 1000
		onTriggered: filteredCityListModel.filterString = cityNameInput.text
	}

	onVisibleChanged: {
		if (visible && !cityListLoaded && !loadingCityList) {
			loadProvinceCityList()
		}
	}


	contentItem: ColumnLayout {
		LinkText {
			text: i18n("Fetched from <a href=\"%1\">%1</a>", "https://weather.gc.ca/canada_e.html")
		}

		QQC2.TabBar {
			id: provinceTabView
			Layout.fillWidth: true
			Repeater {
				id: provinceRepeater
				model: ['AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT']
				QQC2.TabButton { text: modelData }
			}
			onCurrentIndexChanged: loadProvinceCityList()
		}

		QQC2.TextField {
			id: cityNameInput
			Layout.fillWidth: true
			text: ''
			placeholderText: i18n("Search")
			onTextChanged: debouceApplyFilter.restart()
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
							text: '<a href="https://weather.gc.ca/city/pages/' + model.id + '_metric_e.html">' + i18n("Open Link") + '</a>'
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


	function loadCityList(provinceUrl) {
		chooseCityDialog.loadingCityList = true
		filteredCityListModel.sourceModel = emptyListModel
		cityListModel.clear()

		Requests.request(provinceUrl, function(err, data) {
			if (err) {
				console.log('[eventcalendar]', 'loadCityList.err', err, data)
				chooseCityDialog.loadingCityList = false
				return
			}
			var cityList = WeatherCanada.parseProvincePage(data)
			for (var i = 0; i < cityList.length; i++) {
				cityListModel.append(cityList[i])
			}

			// link after populating so that each append() doesn't attempt to rebuild the UI.
			filteredCityListModel.sourceModel = cityListModel

			chooseCityDialog.cityListLoaded = true
			chooseCityDialog.loadingCityList = false
		})
	}

	property alias provinceIdList: provinceRepeater.model
	function loadProvinceCityList() {
		var provinceId = provinceIdList[0]
		if (provinceTabView.currentIndex >= 0) {
			provinceId = provinceIdList[provinceTabView.currentIndex]
		}

		var provinceUrl = 'https://weather.gc.ca/forecast/canada/index_e.html?id=' + provinceId
		loadCityList(provinceUrl)
	}
}
