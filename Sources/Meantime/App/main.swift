import AppKit

// Accessory (menu-bar only) app: no Dock icon, no main window.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
