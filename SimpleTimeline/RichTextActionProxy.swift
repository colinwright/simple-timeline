// SimpleTimeline/RichTextActionProxy.swift

import Foundation
import AppKit
import Combine // <-- Add this import statement

class RichTextActionProxy: ObservableObject {
    weak var coordinator: RichTextCoordinator?

    /// A published property that becomes true when the user's selection is inside a link.
    @Published var isLinkSelected: Bool = false

    /// A subject that fires when a link is clicked in an editable text view, signaling a view to open the link editor.
    let editLinkSubject = PassthroughSubject<(text: String, url: String, range: NSRange), Never>()

    func toggleBold() { coordinator?.toggleBold() }
    func toggleItalic() { coordinator?.toggleItalic() }

    /// Adds a new link to the current selection.
    func addLink(urlString: String) {
        coordinator?.addLink(urlString: urlString)
    }

    /// Removes the link from the current text selection.
    func removeLink() {
        coordinator?.removeLink()
    }

    /// Updates an existing link at a given range with a new URL.
    func updateLink(at range: NSRange, with urlString: String) {
        coordinator?.updateLink(at: range, with: urlString)
    }

    /// Gets the plain text string of the user's current selection.
    func getSelectedString() -> String? {
        coordinator?.getSelectedString()
    }
}
