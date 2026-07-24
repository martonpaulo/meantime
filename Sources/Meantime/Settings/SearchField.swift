import AppKit
import SwiftUI

/// A native `NSSearchField` bridged to SwiftUI: real magnifier, clear button, and
/// Escape-to-clear. SwiftUI's `.searchable` needs a `NavigationStack`/toolbar host, which
/// the tab-style Settings window doesn't provide, so it renders unreliably there. This
/// sits inline, directly above the list it filters.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    /// Focuses the field the first time it appears so typing starts immediately.
    var focusesOnAppear = true

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.sendsWholeSearchString = false
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.placeholderString = prompt
        // Only sync the value when the field is not being edited. Rewriting stringValue
        // mid-edit resets the field editor and drops the first (or first few) keystrokes.
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
        guard focusesOnAppear, !context.coordinator.didFocus, let window = nsView.window else {
            return
        }
        context.coordinator.didFocus = true
        DispatchQueue.main.async { window.makeFirstResponder(nsView) }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>
        var didFocus = false

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
