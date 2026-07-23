import Foundation
import Observation
import Sparkle

/// Wraps Sparkle for the direct-download build. Updates only start from a real,
/// updatable bundle (one that ships a feed URL and public key), so development
/// runs stay inert. Observable so the Updates section can render live state.
@MainActor
@Observable
final class UpdateManager {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    init() {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        if let feed, !feed.isEmpty, let key, !key.isEmpty {
            controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        } else {
            controller = nil
        }
    }

    var isAvailable: Bool { controller != nil }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Sparkle persists this itself; mirror it for the settings toggle.
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
