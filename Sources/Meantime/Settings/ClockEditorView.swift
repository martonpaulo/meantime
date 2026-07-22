import SwiftUI
import MeantimeKit

/// Edits one clock: its name, emoji, menu-bar presentation, and whether it is
/// pinned to the menu bar. Empty name/emoji fall back to the zone's defaults.
struct ClockEditorView: View {
    @Binding var clock: WorldClock
    let formatter: ClockFormatter

    var body: some View {
        Form {
            TextField("Label", text: $clock.customLabel.orEmpty(),
                      prompt: Text(CityLabel.name(for: clock.timeZoneID)))

            TextField("Emoji", text: $clock.customEmoji.orEmpty(),
                      prompt: Text(RegionFlag.emoji(for: clock.timeZoneID)))
                .frame(maxWidth: 120, alignment: .leading)

            Picker("Menu bar", selection: $clock.renderMode) {
                Text("Flag + time").tag(ClockRenderMode.flagAndTime)
                Text("Time only").tag(ClockRenderMode.timeOnly)
                Text("Clock only").tag(ClockRenderMode.analogClock)
            }

            Toggle("Show in menu bar", isOn: $clock.isPinned)
        }
        .formStyle(.grouped)
    }
}
