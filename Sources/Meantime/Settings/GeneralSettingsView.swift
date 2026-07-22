import SwiftUI
import MeantimeKit

/// Startup, updates, reset, and about. Launch-at-login reflects the real system
/// state so an external change (e.g. System Settings) stays in sync.
struct GeneralSettingsView: View {
    @Environment(Preferences.self) private var preferences
    let updateManager: UpdateManager

    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Meantime at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        try? LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
            }

            if updateManager.canCheckForUpdates {
                Section("Updates") {
                    Button("Check for Updates…") { updateManager.checkForUpdates() }
                }
            }

            Section("Reset") {
                Button("Restore Defaults", role: .destructive) {
                    preferences.restoreDefaults()
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("Meantime on GitHub", destination: URL(string: "https://github.com/martonpaulo/meantime")!)
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
