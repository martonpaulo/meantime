import SwiftUI

/// Identity, version, and project links.
struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Token.Space.lg) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityLabel("Meantime application icon")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Meantime")
                            .font(.title2.weight(.semibold))
                        Text("World clocks in your menu bar.")
                            .foregroundStyle(.secondary)
                        Text("Developed by Marton Paulo")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 3)
                    }
                }
                .padding(.vertical, Token.Space.xs)
                LabeledContent("Version", value: "\(version) (build \(build))")
                LabeledContent("Bundle identifier",
                               value: Bundle.main.bundleIdentifier ?? "com.perso.meantime")
            }

            Section {
                Link("Meantime Website",
                     destination: URL(string: "https://martonpaulo.github.io/meantime/")!)
                Link("Meantime on GitHub",
                     destination: URL(string: "https://github.com/martonpaulo/meantime")!)
                Link("Report an Issue",
                     destination: URL(string: "https://github.com/martonpaulo/meantime/issues")!)
                Link("Latest Release",
                     destination: URL(string: "https://github.com/martonpaulo/meantime/releases/latest")!)
            }

            Section {
                LabeledContent("License", value: "MIT")
                Text("Release builds bundle Sparkle for automatic updates.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("© 2026 Marton Paulo. Free and open source under the MIT license.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: Token.Size.paneWidth)
        .fixedSize()
    }
}
