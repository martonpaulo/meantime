import SwiftUI
import MeantimeKit

/// Edits one clock in a sheet: identity, menu-bar presentation, and scheduled
/// hours. Every change writes through immediately; Done just dismisses.
struct ClockEditorSheet: View {
    @Binding var clock: WorldClock
    let formatter: ClockFormatter
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Token.Space.sm) {
                Text(clock.displayEmoji)
                VStack(alignment: .leading, spacing: 0) {
                    Text(clock.displayLabel).font(.headline)
                    Text(clock.timeZoneID)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Token.Space.lg)

            Form {
                Section {
                    TextField("Label", text: $clock.customLabel.orEmpty(),
                              prompt: Text(CityLabel.name(for: clock.timeZoneID)))
                    TextField("Emoji", text: $clock.customEmoji.orEmpty(),
                              prompt: Text(RegionFlag.emoji(for: clock.timeZoneID)))
                } footer: {
                    Text("Leave empty to use the city name and its region's flag.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Menu Bar") {
                    Toggle("Show in menu bar", isOn: $clock.isPinned)
                    Picker("Style", selection: $clock.renderMode) {
                        Text("Flag and time").tag(ClockRenderMode.flagAndTime)
                        Text("Time only").tag(ClockRenderMode.timeOnly)
                        Text("Analog clock face").tag(ClockRenderMode.analogClock)
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(!clock.isPinned)
                }

                ScheduleSection(clock: $clock)
            }
            .formStyle(.grouped)
            .scrollDisabled(true) // the sheet sizes to content — no inner scroll bar

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Token.Space.lg)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            // ⌘W and Escape both dismiss the sheet, like any transient window.
            Group {
                Button("", action: onDone).keyboardShortcut("w", modifiers: .command)
                Button("", action: onDone).keyboardShortcut(.cancelAction)
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

/// Scheduled menu-bar hours, expressed in the clock's own time zone.
private struct ScheduleSection: View {
    @Binding var clock: WorldClock

    private var scheduleEnabled: Binding<Bool> {
        Binding(
            get: { !clock.activeWindows.isEmpty },
            set: { enabled in
                if enabled, clock.activeWindows.isEmpty {
                    // A sensible starting window: 9:00–17:00.
                    clock.activeWindows = [ActiveWindow(startMinute: 9 * 60, endMinute: 17 * 60)]
                } else if !enabled {
                    clock.activeWindows = []
                }
            }
        )
    }

    var body: some View {
        Section {
            Toggle("Only show at scheduled hours", isOn: scheduleEnabled)
                .disabled(!clock.isPinned)

            ForEach($clock.activeWindows) { $window in
                HStack(spacing: Token.Space.sm) {
                    DatePicker("From", selection: minuteBinding($window.startMinute),
                               displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    Text("to").foregroundStyle(.secondary)
                    DatePicker("To", selection: minuteBinding($window.endMinute),
                               displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    Spacer()
                    Button {
                        clock.activeWindows.removeAll { $0.id == window.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove hours")
                }
            }

            if !clock.activeWindows.isEmpty {
                Button {
                    clock.activeWindows.append(ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60))
                } label: {
                    Label("Add Hours", systemImage: "plus")
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Times are in this clock's own time zone — “8:00 to 12:00” means 8 AM to noon in \(CityLabel.name(for: clock.timeZoneID)). Outside these hours the clock leaves the menu bar but stays in the dropdown.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// Bridges a minute-of-day to the hour/minute date picker.
    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { ScheduleTime.date(fromMinute: minute.wrappedValue) },
            set: { minute.wrappedValue = ScheduleTime.minute(from: $0) }
        )
    }
}
