import SwiftUI
import MeantimeKit

/// Startup, updates, and reset. Launch-at-login reflects the real system state
/// so an external change (System Settings) stays in sync.
struct GeneralPane: View {
    @Environment(Preferences.self) private var preferences
    let updateManager: UpdateManager

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var launchAtLoginFailed = false
    @State private var restoreConfirmationShown = false
    @State private var automaticChecks = false

    var body: some View {
        Form {
            Section {
                Toggle("Open Meantime at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LoginItem.setEnabled(newValue)
                            launchAtLoginFailed = false
                        } catch {
                            launchAtLoginFailed = true
                        }
                        launchAtLogin = LoginItem.isEnabled
                    }
                if launchAtLoginFailed {
                    Text("Meantime couldn't be added to Login Items. Move it to Applications, then try again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Update checks use GitHub and are Meantime's only network activity. No accounts or telemetry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        .onAppear { automaticChecks = updateManager.automaticallyChecksForUpdates }
    }
}
