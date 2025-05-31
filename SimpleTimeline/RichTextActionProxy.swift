import Foundation
import AppKit // For NSTextView

class RichTextActionProxy: ObservableObject {
    weak var coordinator: RichTextCoordinator?

    func toggleBold() { coordinator?.toggleBold() }
    func toggleItalic() { coordinator?.toggleItalic() }
    func addLink(urlString: String) { coordinator?.addLink(urlString: urlString) }
    func getSelectedString() -> String? { coordinator?.getSelectedString() }
}
