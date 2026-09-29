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
	// previously. The device authorization flow (no redirect URI, no local server) was tried
	// first, but Google's device flow only accepts an allowlisted subset of scopes and
	// rejects the Tasks scope outright ("Invalid device flow scope"), confirmed live - not
	// documented anywhere, and not something we can configure around. So: the loopback
	// redirect flow instead, which Google recommends generally for desktop apps and has no
	// such scope restriction. https://developers.google.com/identity/protocols/oauth2/native-app
	readonly property int oauthLoopbackPort: 48212
	readonly property string oauthResultFile: '/tmp/plasma-eventcalendar-oauth-result-' + oauthLoopbackPort
	readonly property string oauthRedirectUri: 'http://127.0.0.1:' + oauthLoopbackPort
	property bool loggingIn: false

	ExecUtil { id: oauthExecutable }

	readonly property string authorizationCodeUrl: {
		var url = 'https://accounts.google.com/o/oauth2/v2/auth'
		url += '?scope=' + encodeURIComponent('https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks')
		url += '&response_type=code'
		url += '&redirect_uri=' + encodeURIComponent(oauthRedirectUri)
		url += '&client_id=' + encodeURIComponent(plasmoid.configuration.latestClientId)
		return url
	}

	function describeLoginError(reason) {
		if (reason === 'access_denied') {
			return i18n("Google login was cancelled.")
		} else if (reason === 'port_in_use') {
			return i18n("Could not start the local login listener (port %1 is already in use). Close whatever's using it and try again.", oauthLoopbackPort)
		} else if (reason === 'timeout') {
			return i18n("Google login timed out. Please try again.")
		} else {
			return i18n("Google login failed: %1", reason)
		}
	}

	// Plasma's "executable" DataSource engine only reports a command's result once the
	// process exits - confirmed live that it never reliably does so for this specific
	// long-running/blocking script (every other command in this app is near-instant, this
	// one blocks for however long the user takes in the browser). So the listener is
	// launched backgrounded (the launch itself returns immediately, matching the pattern
	// that's proven to work) and its result is picked up by polling a result file with
	// quick, separate commands instead of waiting on this one long-lived process directly.
	function login() {
		if (loggingIn) {
			return
		}
		loggingIn = true
		var scriptPath = ('' + Qt.resolvedUrl("../../scripts/oauth_redirect_listener.py")).replace('file://', '')
		var launchCmd = [
			'python3', scriptPath,
			'--port', oauthLoopbackPort,
			'--auth-url', authorizationCodeUrl,
			'--result-file', oauthResultFile,
		].map(oauthExecutable.wrapToken).join(' ')
		oauthExecutable.exec('rm -f ' + oauthExecutable.wrapToken(oauthResultFile) + '; ' + launchCmd + ' > /dev/null 2>&1 &')
		pollLoginResultTimer.attempts = 0
		pollLoginResultTimer.start()
	}

	function cancelLogin() {
		pollLoginResultTimer.stop()
		loggingIn = false
	}

	Timer {
		id: pollLoginResultTimer
		interval: 1000
		repeat: true
		property int attempts: 0
		onTriggered: {
			attempts += 1
			if (attempts > 200) { // matches the script's own 180s internal timeout, plus slack
				stop()
				loggingIn = false
				session.error(describeLoginError('timeout'))
				return
			}
			oauthExecutable.exec('cat ' + oauthExecutable.wrapToken(oauthResultFile) + ' 2>/dev/null', function(cmd, exitCode, exitStatus, stdout, stderr) {
				var line = stdout.trim()
				if (!line) {
					return // Not written yet; keep polling.
				}
				pollLoginResultTimer.stop()
				loggingIn = false
				oauthExecutable.exec('rm -f ' + oauthExecutable.wrapToken(oauthResultFile))
				if (line.indexOf('CODE:') === 0) {
					session.fetchAccessToken({
						authorizationCode: line.substr('CODE:'.length),
					})
				} else if (line.indexOf('ERROR:') === 0) {
					session.error(describeLoginError(line.substr('ERROR:'.length)))
				} else {
					session.error(i18n("Google login failed: unexpected response from the local login listener."))
				}
			})
		}
	}

	function fetchAccessToken(args) {
		var url = 'https://oauth2.googleapis.com/token'
		Requests.post({
			url: url,
			data: {
				client_id: plasmoid.configuration.latestClientId,
				client_secret: plasmoid.configuration.latestClientSecret,
				code: args.authorizationCode,
				grant_type: 'authorization_code',
				redirect_uri: oauthRedirectUri,
			},
		}, function(err, data, xhr) {
			logger.debug('/oauth2/token Response', data)

			try {
				data = JSON.parse(data)
			} catch (e) {
				handleError('Error parsing /oauth2/token data as JSON', null)
				return
			}
			if (data && data.error) {
				handleError(data.error_description || data.error, data)
				return
			}
			if (err) {
				handleError(err, null)
				return
			}

			updateAccessToken(data)
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
