#if DEBUG
import Foundation
import ServiceManagement

/// Debug-only check for the login-item contract (issue #18), driving the
/// production `LoginItem` adapter against fake service closures. It counts
/// service calls, so "refreshing never registers anything" is proved rather
/// than asserted. The owner's real Login Items registration is never touched.
@MainActor
enum LoginItemDiagnostic {
    /// A scriptable stand-in for `SMAppService.mainApp`.
    private final class FakeService {
        var status: SMAppService.Status
        var registerResult: SMAppService.Status?
        var registerThrows = false
        var unregisterThrows = false
        private(set) var registerCalls = 0
        private(set) var unregisterCalls = 0
        private(set) var openSettingsCalls = 0
        private(set) var statusReads = 0

        init(status: SMAppService.Status) { self.status = status }

        var service: LoginItem.Service {
            LoginItem.Service(
                status: { [self] in statusReads += 1; return status },
                register: { [self] in
                    registerCalls += 1
                    if registerThrows { throw CocoaError(.fileNoSuchFile) }
                    status = registerResult ?? .enabled
                },
                unregister: { [self] in
                    unregisterCalls += 1
                    if unregisterThrows { throw CocoaError(.fileNoSuchFile) }
                    status = .notRegistered
                },
                openSettings: { [self] in openSettingsCalls += 1 })
        }
    }

    static func run() -> Bool {
        var passed = true
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "  pass" : "  FAIL")  \(label)")
            passed = passed && condition
        }

        // Every system status renders as itself, and reading never mutates.
        let expected: [(SMAppService.Status, LoginItemStatus)] = [
            (.enabled, .enabled), (.notRegistered, .notRegistered),
            (.requiresApproval, .requiresApproval), (.notFound, .unavailable),
        ]
        for (system, rendered) in expected {
            let fake = FakeService(status: system)
            let item = LoginItem(service: fake.service)
            check(item.status == rendered, "\(system) renders as \(rendered)")
            for _ in 0 ..< 5 { item.refresh() }
            check(fake.registerCalls == 0 && fake.unregisterCalls == 0,
                  "displaying and refreshing \(system) makes no registration call")
        }

        // Pending approval is its own state, not a silent off and not an error.
        do {
            let fake = FakeService(status: .requiresApproval)
            let item = LoginItem(service: fake.service)
            check(item.status == .requiresApproval && item.lastFailure == nil,
                  "pending approval is not reported as a failure")
            item.openLoginItemsSettings()
            check(fake.openSettingsCalls == 1, "the Login Items button opens settings once")
            check(fake.registerCalls == 0, "opening settings registers nothing")
        }

        // One user action, at most one mutation.
        do {
            let fake = FakeService(status: .notRegistered)
            let item = LoginItem(service: fake.service)
            item.request(enabled: true)
            check(item.status == .enabled && fake.registerCalls == 1, "enabling registers once")
            item.request(enabled: true)
            check(fake.registerCalls == 1, "enabling again registers nothing")
            item.request(enabled: false)
            check(item.status == .notRegistered && fake.unregisterCalls == 1, "disabling unregisters once")
            item.request(enabled: false)
            check(fake.unregisterCalls == 1, "disabling again unregisters nothing")
        }

        // Registration that comes back pending must not look enabled.
        do {
            let fake = FakeService(status: .notRegistered)
            fake.registerResult = .requiresApproval
            let item = LoginItem(service: fake.service)
            item.request(enabled: true)
            check(item.status == .requiresApproval, "a registration awaiting approval renders as pending")
            check(item.lastFailure == nil, "awaiting approval is not an error")
            for _ in 0 ..< 3 { item.refresh() }
            check(fake.registerCalls == 1, "rendering pending approval does not register again")
            // Turning the toggle off while pending cancels the registration.
            item.request(enabled: false)
            check(fake.unregisterCalls == 1 && item.status == .notRegistered,
                  "cancelling a pending approval unregisters")
        }

        // Failures name the action that failed.
        do {
            let fake = FakeService(status: .notRegistered)
            fake.registerThrows = true
            let item = LoginItem(service: fake.service)
            item.request(enabled: true)
            check(item.lastFailure == .enable, "a failed enable reports an enable failure")
            item.refresh()
            check(item.lastFailure == .enable, "a read does not silence an unresolved failure")
            fake.registerThrows = false
            item.request(enabled: true)
            check(item.lastFailure == nil && item.status == .enabled, "a later success clears it")

            fake.unregisterThrows = true
            item.request(enabled: false)
            check(item.lastFailure == .disable, "a failed disable reports a disable failure")
            // Resolved externally: the system now proves the requested outcome.
            fake.status = .notRegistered
            item.refresh()
            check(item.lastFailure == nil, "an external change that satisfies the request clears it")
        }

        // An external change is picked up by a read-only refresh.
        do {
            let fake = FakeService(status: .enabled)
            let item = LoginItem(service: fake.service)
            fake.status = .requiresApproval          // consent revoked in System Settings
            item.refresh()
            check(item.status == .requiresApproval, "revoked consent appears after a refresh")
            fake.status = .notRegistered
            item.refresh()
            check(item.status == .notRegistered, "external removal appears after a refresh")
            check(fake.registerCalls == 0 && fake.unregisterCalls == 0,
                  "no refresh changed the registration")
        }
        return passed
    }
}
#endif
