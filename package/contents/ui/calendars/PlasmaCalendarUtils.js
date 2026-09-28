.pragma library

// https://invent.kde.org/plasma/plasma-workspace/-/blob/master/components/calendar/eventpluginsmanager.h
// https://invent.kde.org/plasma/plasma-workspace/-/blob/master/components/calendar/eventpluginsmanager.cpp
//
// Plasma 6 changed EventPluginsManager's model role from "pluginPath" (a full
// ".so" filepath) to "pluginId" (eg. "holidaysevents"), and enabledPlugins /
// populateEnabledPluginsList() now take plugin ids instead of paths. KDE's own
// kconf_update migration (migrate-calendar-to-plugin-id.py) only rewrites the
// desktop's own "enabledCalendarPlugins" key in plasma-org.kde.plasma.desktop-appletsrc,
// not third-party applets like this one, so plasmoid.configuration.enabledCalendarPlugins
// (stored as bare "<id>.so" filenames since our own v72 migration, see config/main.xml)
// needs to keep matching regardless of which format is on disk.

function getPluginFilename(pluginPath) {
	return pluginPath.substr(pluginPath.lastIndexOf('/') + 1)
}

function filenameToPluginIdStem(pluginFilename) {
	// Accepts a bare id ("holidaysevents"), a stored filename ("holidaysevents.so"),
	// or (from a pre-v72 config) a full path ("/usr/.../holidaysevents.so").
	return getPluginFilename(pluginFilename).replace(/\.so$/, '')
}

function pluginIdToFilename(pluginId) {
	return pluginId + '.so'
}

// Pure string conversion (no EventPluginsManager needed), used by ConfigMigration.qml's
// one-time v72 migration to strip full ".so" filepaths down to bare filenames.
function pluginPathToFilenameList(pluginPathList) {
	var pluginFilenameList = []
	for (var i = 0; i < pluginPathList.length; i++) {
		var pluginFilename = getPluginFilename(pluginPathList[i])
		if (pluginFilenameList.indexOf(pluginFilename) == -1) {
			pluginFilenameList.push(pluginFilename)
		}
	}
	return pluginFilenameList
}

function getPluginId(eventPluginsManager, pluginFilenameA) {
	var pluginStem = filenameToPluginIdStem(pluginFilenameA)
	for (var i = 0; i < eventPluginsManager.model.rowCount(); i++) {
		var pluginId = eventPluginsManager.model.get(i, 'pluginId')
		// console.log('\t\t', i, pluginId)
		if (pluginStem == pluginId) {
			return pluginId
		}
	}

	// Plugin not installed
	return null
}

function pluginFilenameToIdList(eventPluginsManager, pluginFilenameList) {
	var pluginIdList = []
	for (var i = 0; i < pluginFilenameList.length; i++) {
		var pluginFilename = pluginFilenameList[i]
		var pluginId = getPluginId(eventPluginsManager, pluginFilename)
		if (!pluginId) {
			console.log('[eventcalendar] Tried to load ', pluginFilename, ' however the plasma calendar plugin is not installed.')
			continue
		}
		if (pluginIdList.indexOf(pluginId) == -1) {
			pluginIdList.push(pluginId)
		}
	}
	return pluginIdList
}

function pluginIdListToFilenameList(pluginIdList) {
	var pluginFilenameList = []
	for (var i = 0; i < pluginIdList.length; i++) {
		var pluginFilename = pluginIdToFilename(pluginIdList[i])
		if (pluginFilenameList.indexOf(pluginFilename) == -1) {
			pluginFilenameList.push(pluginFilename)
		}
	}
	return pluginFilenameList
}

function populateEnabledPluginsByFilename(eventPluginsManager, pluginFilenameList) {
	var pluginIdList = pluginFilenameToIdList(eventPluginsManager, pluginFilenameList)
	eventPluginsManager.populateEnabledPluginsList(pluginIdList)
}

function setEnabledPluginsByFilename(eventPluginsManager, pluginFilenameList) {
	var pluginIdList = pluginFilenameToIdList(eventPluginsManager, pluginFilenameList)
	eventPluginsManager.enabledPlugins = pluginIdList
}
