import Foundation
import Sparkle

/// Wraps Sparkle for the direct-download build. Updates only start from a real,
/// updatable bundle (one that ships a feed URL), so development runs and any
/// future non-Sparkle build stay inert.
@MainActor
final class UpdateManager {
    private let controller: SPUStandardUpdaterController?

    init() {
        // Start Sparkle only from a real, updatable bundle: one that ships both a
        // feed URL and a public key (filled by `make keys`). Development runs and
        // an unkeyed scaffold stay inert.
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        if let feed, !feed.isEmpty, let key, !key.isEmpty {
            controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        } else {
            controller = nil
        }
    }

    var canCheckForUpdates: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
