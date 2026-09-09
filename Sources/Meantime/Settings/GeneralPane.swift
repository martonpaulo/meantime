import SwiftUI
import MeantimeKit

/// Startup, updates, and reset. Launch-at-login renders the real system status,
/// including a registration still waiting for the user's approval, and re-reads
/// it whenever the user could have changed it in System Settings.
struct GeneralPane: View {
    @Environment(Preferences.self) private var preferences
    let updateManager: UpdateManager

    @State private var loginItem = LoginItem()
    @State private var restoreConfirmationShown = false
    @State private var automaticChecks: Bool

    @MainActor
    init(updateManager: UpdateManager) {
        self.updateManager = updateManager
        // Seed from Sparkle's real state so the toggle never renders off and then flips.
        _automaticChecks = State(initialValue: updateManager.automaticallyChecksForUpdates)
    }

    var body: some View {
        Form {
            Section {
                // The setter runs only on an explicit user action; rendering and
                // refreshing never register or unregister anything.
                Toggle("Open Meantime at login", isOn: Binding(
                    get: { loginItem.status == .enabled },
                    set: { loginItem.request(enabled: $0) }))
                    .disabled(loginItem.status == .unavailable)

                if loginItem.status == .requiresApproval {
                    LabeledContent {
                        Button("Open Login Items…") { loginItem.openLoginItemsSettings() }
                    } label: {
                        Text("Waiting for your approval in System Settings. Meantime will not open at login until you allow it.")
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.secondaryText)
                    }
                }
                if loginItem.status == .unavailable {
                    Text("Login Items are available in an installed release of Meantime, not in development builds.")
                        .font(Token.Font.secondary)
                        .foregroundStyle(Token.Color.secondaryText)
                }
                if let failure = loginItem.lastFailure {
                    Text(failure == .enable
                         ? "Meantime couldn't be added to Login Items. Move it to Applications, then try again."
                         : "Meantime couldn't be removed from Login Items. Remove it in System Settings instead.")
                        .font(Token.Font.secondary)
                        .foregroundStyle(Token.Color.secondaryText)
                }
            }

            Section {
                Toggle("Automatically check for updates", isOn: $automaticChecks)
                    .onChange(of: automaticChecks) { _, newValue in
                        updateManager.automaticallyChecksForUpdates = newValue
                    }
                    .disabled(!updateManager.isAvailable)
                LabeledContent("Version \(updateManager.currentVersion)") {
                    Button("Check for Updates…") { updateManager.checkForUpdates() }
                        .disabled(!updateManager.isAvailable)
                }
                if !updateManager.isAvailable {
                    Text("Updates are available in an installed release of Meantime, not in development builds.")
                        .font(Token.Font.secondary)
                        .foregroundStyle(Token.Color.secondaryText)
                }
            } footer: {
                Text("Update checks use GitHub and are Meantime's only network activity. No accounts or telemetry.")
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
            }

            Section {
                LabeledContent("Reset clocks, format, and appearance") {
                    Button("Restore Defaults…", role: .destructive) {
                        restoreConfirmationShown = true
                    }
                }
                .confirmationDialog("Restore all settings to their defaults?",
                                    isPresented: $restoreConfirmationShown) {
                    Button("Restore Defaults", role: .destructive) {
                        preferences.restoreDefaults()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your clocks, format, and appearance return to the defaults. Login and update settings are not affected.")
                }
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .frame(width: Token.Size.paneWidth, height: Token.Size.paneHeight)
        // The system owns this consent, so re-read it whenever the user could
        // have changed it elsewhere: on first presentation, on returning to this
        // retained pane, and on coming back from System Settings. Reads only:
        // no timer, no polling, and never a registration.
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: .settingsPaneDidAppear)) { _ in loginItem.refresh() }
    }
}
