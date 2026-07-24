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

    func makeNSView(context: Context) -> AutoFocusSearchField {
        let field = AutoFocusSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.sendsWholeSearchString = false
        field.focusesOnAppear = focusesOnAppear
        return field
    }

    func updateNSView(_ nsView: AutoFocusSearchField, context: Context) {
        nsView.placeholderString = prompt
        nsView.focusesOnAppear = focusesOnAppear
        // Sync the value only when the field is not being edited. Rewriting
        // `stringValue` mid-edit resets the field editor and drops keystrokes.
        // Focusing is handled by the view itself (see AutoFocusSearchField), never
        // here: scheduling `makeFirstResponder` from an update triggered by the
        // first keystroke re-installs the field editor and clears what was typed.
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// A search field that grabs focus once, exactly when it enters a window, so the
/// initial focus never races a SwiftUI update. Because focusing happens here and
/// not from `updateNSView`, no re-render (including the one caused by the first
/// keystroke) can re-install the field editor and discard buffered characters.
final class AutoFocusSearchField: NSSearchField {
    var focusesOnAppear = false
    private var didFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusesOnAppear, !didFocus, let window else { return }
        didFocus = true
        // Defer one runloop turn so the field is fully installed in the responder
        // chain; guard against stealing focus from an edit already under way.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentEditor() == nil else { return }
            window.makeFirstResponder(self)
        }
    }
}
