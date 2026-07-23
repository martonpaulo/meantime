import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`: the modern, sandbox-safe way to
/// launch the app at login. Only works from a real installed bundle, so it is a
/// no-op-ish surface during `swift run`.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        switch (enabled, SMAppService.mainApp.status) {
        case (true, let status) where status != .enabled:
            try SMAppService.mainApp.register()
        case (false, .enabled):
            try SMAppService.mainApp.unregister()
        default:
            break // already in the desired state
        }
    }
}
