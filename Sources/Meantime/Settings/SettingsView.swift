import SwiftUI
import MeantimeKit

/// The settings window: three native tabs. Every tab reads the shared
/// `Preferences` from the environment and mutates it directly, which persists
/// and updates the menu bar live.
struct SettingsView: View {
    let formatter: ClockFormatter
    let updateManager: UpdateManager

    var body: some View {
        TabView {
            ClocksSettingsView(formatter: formatter)
                .tabItem { Label("Clocks", systemImage: "globe") }
            FormatSettingsView(formatter: formatter)
                .tabItem { Label("Format", systemImage: "textformat") }
            GeneralSettingsView(updateManager: updateManager)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 560)
    }
}
