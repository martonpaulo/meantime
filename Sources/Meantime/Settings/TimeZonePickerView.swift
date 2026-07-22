import SwiftUI
import MeantimeKit

/// A searchable list of every known time zone, shown as flag + city + identifier.
/// Selecting one adds a clock. Search matches the city name or the identifier.
struct TimeZonePickerView: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""

    private var identifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.lowercased().contains(trimmed) || CityLabel.name(for: $0).lowercased().contains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Clock").font(.headline)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
            .padding(Token.Space.md)

            HStack(spacing: Token.Space.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(Token.Color.secondaryText)
                TextField("Search cities or zones", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, Token.Space.md)
            .padding(.bottom, Token.Space.sm)

            Divider()

            List(identifiers, id: \.self) { identifier in
                Button { onSelect(identifier) } label: {
                    HStack(spacing: Token.Space.sm) {
                        Text(RegionFlag.emoji(for: identifier))
                        Text(CityLabel.name(for: identifier))
                        Spacer()
                        Text(identifier)
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 440, height: 480)
    }
}
