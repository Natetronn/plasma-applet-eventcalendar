import QtQuick
import QtQuick.Controls as QQC2

// A thin imperative wrapper around QQC2.Menu, rebuilding the API this codebase used to get
// from Plasma 5's org.kde.plasma.components 2.0 PlasmaComponents.ContextMenu/MenuItem (which
// have no Plasma 6 equivalent). https://doc.qt.io/qt-6/qml-qtquick-controls-menu.html
QQC2.Menu {
	id: contextMenu

	signal populate(var contextMenu)

	// Marks this as a lib/ContextMenu.qml instance (rather than a plain MenuItem), so
	// addMenuItem() can tell whether to attach it as a submenu (addMenu) or a leaf item (addItem).
	readonly property bool isContextMenu: true
	// Self-reference kept for API compatibility with call sites written against the old
	// QQC1-based ContextMenu, where a submenu's "item" and its "menu" were separate objects
	// (eg. `deleteMenuItem.subMenu.addMenuItem(menuItem)`).
	property var subMenu: contextMenu
	property alias text: contextMenu.title
	// Note: "icon" is already a FINAL property on QQC2.Menu, so this cosmetic
	// submenu-header icon (never rendered by Menu itself) uses a different name.
	property string menuIcon: ""

	property var menuItemComponent: Component {
		MenuItem {}
	}

	function newSeperator(parentMenu) {
		return Qt.createQmlObject("import QtQuick.Controls as QQC2; QQC2.MenuSeparator {}", parentMenu || contextMenu)
	}

	function newMenuItem(parentMenu, properties) {
		return menuItemComponent.createObject(parentMenu || contextMenu, properties || {})
	}

	function newSubMenu(parentMenu, properties) {
		return Qt.createComponent("ContextMenu.qml").createObject(parentMenu || contextMenu, properties || {})
	}

	function addMenuItem(item) {
		if (item.isContextMenu === true) {
			contextMenu.addMenu(item)
		} else {
			contextMenu.addItem(item)
		}
	}

	function clearMenuItems() {
		contextMenu.clear()
	}

	function loadMenu() {
		clearMenuItems()
		populate(contextMenu)
	}

	function show(x, y) {
		loadMenu()
		if (count > 0) {
			popup(x, y)
		}
	}
}
