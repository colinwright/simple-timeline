// RichTextEditorView.swift

import SwiftUI
import AppKit

// The Coordinator will handle delegate methods and actions.
class RichTextCoordinator: NSObject, NSTextViewDelegate, ObservableObject {
    @Binding var rtfData: Data?
    weak var textView: NSTextView? // Weak reference to the NSTextView

    init(rtfData: Binding<Data?>) {
        _rtfData = rtfData
    }

    // Called when the text changes in the NSTextView
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let contentRange = NSRange(location: 0, length: textView.string.count)
        self.rtfData = textView.rtf(from: contentRange)
    }

    // Action: Toggle Bold
    func toggleBold() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange()
        
        var currentAttributes = selectedRange.length > 0 ?
            textView.textStorage?.attributes(at: selectedRange.location, effectiveRange: nil) :
            textView.typingAttributes
        currentAttributes = currentAttributes ?? textView.typingAttributes
        
        let currentFont = currentAttributes?[.font] as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        let fontManager = NSFontManager.shared
        let newFont: NSFont
        if currentFont.fontDescriptor.symbolicTraits.contains(.bold) {
            newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
        } else {
            newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
        }
        
        // Apply to selection or typing attributes
        if selectedRange.length > 0 {
            textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange)
        } else {
            var typingAttributes = textView.typingAttributes
            typingAttributes[.font] = newFont
            textView.typingAttributes = typingAttributes
        }
    }

    // Action: Toggle Italic
    func toggleItalic() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange()

        var currentAttributes = selectedRange.length > 0 ?
            textView.textStorage?.attributes(at: selectedRange.location, effectiveRange: nil) :
            textView.typingAttributes
        currentAttributes = currentAttributes ?? textView.typingAttributes
        
        let currentFont = currentAttributes?[.font] as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

        let fontManager = NSFontManager.shared
        let newFont: NSFont
        if currentFont.fontDescriptor.symbolicTraits.contains(.italic) {
            newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
        } else {
            newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
        }
        
        if selectedRange.length > 0 {
            textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange)
        } else {
            var typingAttributes = textView.typingAttributes
            typingAttributes[.font] = newFont
            textView.typingAttributes = typingAttributes
        }
    }
    
    // UPDATED: Implement Link Action
    func addLink(urlString: String) {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange()

        // Ensure the URL string is valid and can be converted to a URL
        var properURLString = urlString
        if !properURLString.hasPrefix("http://") && !properURLString.hasPrefix("https://") {
            properURLString = "https://" + properURLString
        }
        
        guard let url = URL(string: properURLString) else {
            print("Invalid URL string: \(properURLString)")
            // Optionally, show an alert to the user here
            return
        }
        
        if selectedRange.length > 0 {
            // Apply the link attribute to the selected text
            textView.textStorage?.addAttribute(.link, value: url, range: selectedRange)
            // Optionally, add styling for the link (e.g., blue color, underline)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.linkColor, range: selectedRange)
            textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            
            // Trigger a textDidChange notification manually if needed, or rely on NSTextStorage's own mechanisms
            // Forcing an update to ensure rtfData binding is refreshed:
            let contentRange = NSRange(location: 0, length: textView.string.count)
            self.rtfData = textView.rtf(from: contentRange)
        } else {
            // If no text is selected, you could insert the URL as linked text.
            // For this example, we'll require text to be selected.
            // You could show an alert to the user.
            let alert = NSAlert()
            alert.messageText = "Add Link"
            alert.informativeText = "Please select some text to apply the link to."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            print("Link: Please select text to apply the link to.")
        }
    }
}

// RichTextEditorView struct remains the same as previously provided
struct RichTextEditorView: NSViewRepresentable {
    @Binding var rtfData: Data?
    @ObservedObject var coordinator: RichTextCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        if let nsTextView = scrollView.documentView as? NSTextView {
            
            nsTextView.delegate = coordinator
            coordinator.textView = nsTextView
            
            nsTextView.isRichText = true
            nsTextView.allowsImageEditing = false
            nsTextView.isEditable = true
            nsTextView.isSelectable = true
            nsTextView.font = NSFont.userFont(ofSize: 14)
            nsTextView.textColor = NSColor.textColor
            nsTextView.backgroundColor = NSColor.textBackgroundColor
            nsTextView.usesAdaptiveColorMappingForDarkAppearance = true

            if let data = rtfData,
               let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                nsTextView.textStorage?.setAttributedString(attributedString)
            } else {
                nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            }
        }
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let nsTextView = nsView.documentView as? NSTextView,
              let textStorage = nsTextView.textStorage else { return }

        let currentTextViewData = textStorage.rtf(from: NSRange(location: 0, length: textStorage.length), documentAttributes: [:])
        
        let isFirstResponder = nsTextView.window?.firstResponder == nsTextView.enclosingScrollView?.documentView

        // Only update if external data changed AND the view isn't focused/being edited
        // or if the data is nil and needs to be cleared
        if (rtfData == nil && !textStorage.string.isEmpty && !isFirstResponder) ||
           (rtfData != currentTextViewData && !isFirstResponder) {
            
            textStorage.beginEditing()
            if let data = rtfData,
               let newAttributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                textStorage.setAttributedString(newAttributedString)
            } else {
                textStorage.setAttributedString(NSAttributedString(string: ""))
            }
            textStorage.endEditing()
        }
    }
}
