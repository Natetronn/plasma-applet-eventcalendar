import QtQuick

import "../lib"
import "../lib/Requests.js" as Requests

Item {
	id: session

	Logger {
		id: logger
		showDebug: plasmoid.configuration.debugging
	}

	// Active Session
	readonly property bool isLoggedIn: !!plasmoid.configuration.accessToken
	readonly property bool needsRelog: {
		if (plasmoid.configuration.accessToken && plasmoid.configuration.latestClientId != plasmoid.configuration.sessionClientId) {
			return true
		} else if (!plasmoid.configuration.accessToken && plasmoid.configuration.access_token) {
			return true
		} else {
			return false
		}
	}

	// Data
	property var m_calendarList: ConfigSerializedString {
		id: m_calendarList
		configKey: 'calendarList'
		defaultValue: []
	}
	property alias calendarList: m_calendarList.value

	property var m_calendarIdList: ConfigSerializedString {
		id: m_calendarIdList
		configKey: 'calendarIdList'
		defaultValue: []

		function serialize() {
			plasmoid.configuration[configKey] = value.join(',')
		}
		function deserialize() {
			value = configValue.split(',')
		}
	}
	property alias calendarIdList: m_calendarIdList.value

	property var m_tasklistList: ConfigSerializedString {
		id: m_tasklistList
		configKey: 'tasklistList'
		defaultValue: []
	}
	property alias tasklistList: m_tasklistList.value

	property var m_tasklistIdList: ConfigSerializedString {
		id: m_tasklistIdList
		configKey: 'tasklistIdList'
		defaultValue: []

		function serialize() {
			plasmoid.configuration[configKey] = value.join(',')
		}
		function deserialize() {
			value = configValue.split(',')
		}
	}
	property alias tasklistIdList: m_tasklistIdList.value


	//--- Signals
	signal newAccessToken()
	signal sessionReset()
	signal error(string err)


	//---
	// Google fully disabled the "out-of-band" (urn:ietf:wg:oauth:2.0:oob) flow used here
	// previously. Rather than requiring a local redirect listener, this uses Google's device
	// authorization flow (the same one CLI tools like gcloud/gh use): no redirect URI, no
	// local server, just a short code the user enters at a Google URL while we poll for them
	// approving it. https://developers.google.com/identity/protocols/oauth2/limited-input-device
	property string deviceCode: ''
	property string userCode: ''
	property string verificationUrl: ''
	property bool loggingIn: false
	property string loginStatusMessage: ''

	Timer {
		id: pollTimer
		repeat: true
		onTriggered: session.pollForToken()
	}

	function login() {
		if (loggingIn) {
			return
		}
		loggingIn = true
		userCode = ''
		verificationUrl = ''
		loginStatusMessage = i18n("Requesting a login code from Google…")
		Requests.post({
			url: 'https://oauth2.googleapis.com/device/code',
			data: {
				client_id: plasmoid.configuration.latestClientId,
				scope: 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks',
			},
		}, function(err, data, xhr) {
			try {
				data = JSON.parse(data)
			} catch (e) {
				data = null
			}
			if (err || !data || data.error) {
				cancelLogin()
				session.error(i18n("Could not start Google login: %1", (data && (data.error_description || data.error)) || err || 'unknown_error'))
				return
			}
			deviceCode = data.device_code
			userCode = data.user_code
			verificationUrl = data.verification_url
			loginStatusMessage = i18n("Waiting for you to approve access…")
			pollTimer.interval = (data.interval || 5) * 1000
			pollTimer.restart()
		})
	}

	function cancelLogin() {
		pollTimer.stop()
		loggingIn = false
		deviceCode = ''
		userCode = ''
		verificationUrl = ''
		loginStatusMessage = ''
	}

	function pollForToken() {
		Requests.post({
			url: 'https://oauth2.googleapis.com/token',
			data: {
				client_id: plasmoid.configuration.latestClientId,
				client_secret: plasmoid.configuration.latestClientSecret,
				device_code: deviceCode,
				grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
			},
		}, function(err, data, xhr) {
			try {
				data = JSON.parse(data)
			} catch (e) {
				return // Transient/malformed response; just try again next poll.
			}
			if (data.access_token) {
				pollTimer.stop()
				loggingIn = false
				loginStatusMessage = ''
				updateAccessToken(data)
			} else if (data.error === 'authorization_pending') {
				// Keep polling; the user hasn't approved (or denied) it yet.
			} else if (data.error === 'slow_down') {
				pollTimer.interval += 5000
			} else {
				// access_denied, expired_token, or anything else Google sends back.
				var reason = data.error_description || data.error || 'unknown_error'
				cancelLogin()
				session.error(i18n("Google login failed: %1", reason))
			}
		})
	}

	function updateAccessToken(data) {
		plasmoid.configuration.sessionClientId = plasmoid.configuration.latestClientId
		plasmoid.configuration.sessionClientSecret = plasmoid.configuration.latestClientSecret
		plasmoid.configuration.accessToken = data.access_token
		plasmoid.configuration.accessTokenType = data.token_type
		plasmoid.configuration.accessTokenExpiresAt = Date.now() + data.expires_in * 1000
		plasmoid.configuration.refreshToken = data.refresh_token
		newAccessToken()
	}

	onNewAccessToken: updateData()

	function updateData() {
		updateCalendarList()
		updateTasklistList()
	}

	function updateCalendarList() {
		logger.debug('updateCalendarList')
		logger.debug('accessToken', plasmoid.configuration.accessToken)
		fetchGCalCalendars({
			accessToken: plasmoid.configuration.accessToken,
		}, function(err, data, xhr) {
			// Check for errors
			if (err || data.error) {
				handleError(err, data)
				return
			}
			m_calendarList.value = data.items
		})
	}

	function fetchGCalCalendars(args, callback) {
		var url = 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
		Requests.getJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			}
		}, function(err, data, xhr) {
			// console.log('fetchGCalCalendars.response', err, data, xhr && xhr.status)
			if (!err && data && data.error) {
				return callback('fetchGCalCalendars error', data, xhr)
			}
			logger.debugJSON('fetchGCalCalendars.response.data', data)
			callback(err, data, xhr)
		})
	}

	function updateTasklistList() {
		logger.debug('updateTasklistList')
		logger.debug('accessToken', plasmoid.configuration.accessToken)
		fetchGoogleTasklistList({
			accessToken: plasmoid.configuration.accessToken,
		}, function(err, data, xhr) {
			// Check for errors
			if (err || data.error) {
				handleError(err, data)
				return
			}
			m_tasklistList.value = data.items
		})
	}

	function fetchGoogleTasklistList(args, callback) {
		var url = 'https://www.googleapis.com/tasks/v1/users/@me/lists'
		Requests.getJSON({
			url: url,
			headers: {
				"Authorization": "Bearer " + args.accessToken,
			}
		}, function(err, data, xhr) {
			console.log('fetchGoogleTasklistList.response', err, data, xhr && xhr.status)
			if (!err && data && data.error) {
				return callback('fetchGoogleTasklistList error', data, xhr)
			}
			logger.debugJSON('fetchGoogleTasklistList.response.data', data)
			callback(err, data, xhr)
		})
	}

	function logout() {
		plasmoid.configuration.sessionClientId = ''
		plasmoid.configuration.sessionClientSecret = ''
		plasmoid.configuration.accessToken = ''
		plasmoid.configuration.accessTokenType = ''
		plasmoid.configuration.accessTokenExpiresAt = 0
		plasmoid.configuration.refreshToken = ''

		// Delete relevant data
		// TODO: only target google calendar data
		// TODO: Make a signal?
		plasmoid.configuration.agendaNewEventLastCalendarId = ''
		calendarList = []
		calendarIdList = []
		tasklistList = []
		tasklistIdList = []
		sessionReset()
	}

	// https://developers.google.com/calendar/v3/errors
	function handleError(err, data) {
		if (data && data.error && data.error_description) {
			var errorMessage = '' + data.error + ' (' + data.error_description + ')'
			session.error(errorMessage)
		} else if (data && data.error && data.error.message && typeof data.error.code !== "undefined") {
			var errorMessage = '' + data.error.message + ' (' + data.error.code + ')'
			session.error(errorMessage)
		} else if (err) {
			session.error(err)
		}
	}
}
