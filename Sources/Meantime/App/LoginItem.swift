import AppKit
import Observation
import ServiceManagement

/// What the system reports about launching Meantime at login.
enum LoginItemStatus: Equatable {
    /// Registered and approved: the app will launch at login.
    case enabled
    /// Not registered. This is the ordinary "off" state.
    case notRegistered
    /// Registered, but the user has not approved it in System Settings yet, or
    /// has revoked approval. The app will not launch until they do.
    case requiresApproval
    /// The service is not available to this copy of the app.
    case unavailable
}

/// Which user action failed, so the message can say what actually went wrong
/// instead of always blaming a failed registration.
enum LoginItemAction: Equatable {
    case enable
    case disable
}

/// Thin adapter over `SMAppService.mainApp`: the modern, sandbox-safe way to
/// launch the app at login. It is the only authority on the state; nothing is
/// cached in preferences, because the consent belongs to the system.
///
/// Reading the status never registers or unregisters anything. Only an explicit
/// user action mutates the registration, so refreshing a retained Settings pane
/// can never quietly change the user's consent.
@MainActor
@Observable
final class LoginItem {
    /// The operations this adapter needs, as closures, so the presentation can
    /// be exercised against every status without touching the real service.
    struct Service {
        var status: () -> SMAppService.Status
        var register: () throws -> Void
        var unregister: () throws -> Void
        var openSettings: () -> Void

        @MainActor
        static let mainApp = Service(
            status: { SMAppService.mainApp.status },
            register: { try SMAppService.mainApp.register() },
            unregister: { try SMAppService.mainApp.unregister() },
            openSettings: { SMAppService.openSystemSettingsLoginItems() })
    }

    private(set) var status: LoginItemStatus = .notRegistered
    /// Set when the last explicit action failed, and cleared only when the
    /// system proves the requested outcome or a later action succeeds.
    private(set) var lastFailure: LoginItemAction?

    @ObservationIgnored private let service: Service

    init(service: Service = .mainApp) {
        self.service = service
        status = Self.map(service.status())
    }

    /// Reads the system state. Never mutates the registration.
    func refresh() {
        let current = Self.map(service.status())
        // A read can retire an error only by proving the requested outcome:
        // otherwise the pane would go quiet while still in the failed state.
        if let failure = lastFailure, Self.satisfies(current, failure) { lastFailure = nil }
        status = current
    }

    /// Applies an explicit user request. At most one service mutation runs.
    func request(enabled: Bool) {
        do {
            if enabled {
                guard status != .enabled else { return }
                try service.register()
            } else {
                // Cancelling a pending approval is an unregister request too.
                guard status == .enabled || status == .requiresApproval else { return }
                try service.unregister()
            }
            lastFailure = nil
        } catch {
            lastFailure = enabled ? .enable : .disable
        }
        status = Self.map(service.status())
    }

    func openLoginItemsSettings() {
        service.openSettings()
    }

    private static func map(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notRegistered
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    private static func satisfies(_ status: LoginItemStatus, _ action: LoginItemAction) -> Bool {
        switch action {
        case .enable: return status == .enabled || status == .requiresApproval
        case .disable: return status == .notRegistered
        }
    }
}
