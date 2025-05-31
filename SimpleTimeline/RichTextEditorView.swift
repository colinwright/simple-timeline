// RichTextEditorView.swift

import SwiftUI
import AppKit

// Ensure NotificationNames.swift has:
// extension Notification.Name {
//     static let navigateToInternalItem = Notification.Name("navigateToInternalItem")
// }

class RichTextCoordinator: NSObject, NSTextViewDelegate, ObservableObject {
    @Binding var rtfData: Data?
    weak var textView: NSTextView?

    init(rtfData: Binding<Data?>) {
        self._rtfData = rtfData
        super.init()
        print("[RichTextCoordinator] Initialized with rtfData binding.")
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let contentRange = NSRange(location: 0, length: textView.string.count)
        let newData = textView.rtf(from: contentRange)
        // print("[RichTextCoordinator] textDidChange - new data length: \(newData?.count ?? 0)")
        self.rtfData = newData
    }

    private func forceUpdateBindingAfterStyleChange() {
        guard let textView = textView else {
            print("[RichTextCoordinator] forceUpdateBindingAfterStyleChange: textView is nil, cannot update binding.")
            return
        }
        let contentRange = NSRange(location: 0, length: textView.string.count)
        let currentDataFromTextView = textView.rtf(from: contentRange)
        // print("[RichTextCoordinator] forceUpdateBindingAfterStyleChange - data length: \(currentDataFromTextView?.count ?? 0)")
        self.rtfData = currentDataFromTextView
    }

    func toggleBold() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange()
        let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont
        let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.bold) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
        if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) }
        else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }
        forceUpdateBindingAfterStyleChange()
    }

    func toggleItalic() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange()
        let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont
        let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.italic) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
        if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) }
        else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }
        forceUpdateBindingAfterStyleChange()
    }
    
    func addLink(urlString: String) {
        guard let textView = textView, textView.isEditable else {
            print("[RichTextCoordinator] addLink: textView is nil or not editable.")
            return
        }
        let selectedRange = textView.selectedRange()
        print("[RichTextCoordinator] addLink: Called with urlString '\(urlString)', selectedRange: location \(selectedRange.location), length \(selectedRange.length)")

        if selectedRange.length > 0 {
            var attributes: [NSAttributedString.Key: Any] = [:]
            if urlString.starts(with: "simpletl://") {
                attributes[.link] = urlString
                print("[RichTextCoordinator] addLink: Applying custom scheme link: \(urlString)")
            } else {
                var properURLString = urlString
                if !properURLString.hasPrefix("http://") && !properURLString.hasPrefix("https://") { properURLString = "https://" + properURLString }
                guard let url = URL(string: properURLString) else {
                    print("[RichTextCoordinator] addLink: Invalid external URL: \(properURLString)")
                    let alert = NSAlert(); alert.messageText = "Invalid URL"; alert.informativeText = "The entered URL is not valid: \(properURLString)"; alert.alertStyle = .warning; alert.addButton(withTitle: "OK"); alert.runModal(); return
                }
                attributes[.link] = url
                print("[RichTextCoordinator] addLink: Applying external URL link: \(url.absoluteString)")
            }
            attributes[.foregroundColor] = NSColor.linkColor
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            
            textView.textStorage?.beginEditing()
            textView.textStorage?.addAttributes(attributes, range: selectedRange)
            textView.textStorage?.endEditing()

            // === DIAGNOSTIC PRINT FOR APPLIED ATTRIBUTES ===
            if let textStorage = textView.textStorage {
                let attributesApplied = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
                print("[RichTextCoordinator] addLink: Attributes actually applied at range \(selectedRange.location), length \(selectedRange.length): \(attributesApplied)")
                if let linkAttr = attributesApplied[.link] {
                    print("[RichTextCoordinator] addLink: Verifying .link attribute value: '\(linkAttr)', type: \(type(of: linkAttr))")
                } else {
                    print("[RichTextCoordinator] addLink: VERIFICATION FAILED - .link attribute NOT FOUND after applying.")
                }
            }
            // ===============================================
            forceUpdateBindingAfterStyleChange()
        } else {
            print("[RichTextCoordinator] addLink: No text selected to apply link.")
            let alert = NSAlert(); alert.messageText = "Add Link"; alert.informativeText = "Please select some text to apply the link to."; alert.alertStyle = .informational; alert.addButton(withTitle: "OK"); alert.runModal()
        }
    }

    func getSelectedString() -> String? {
        guard let textView = textView, textView.selectedRange().length > 0 else { return nil }
        return (textView.string as NSString).substring(with: textView.selectedRange())
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        // === DIAGNOSTIC PRINT AT THE VERY START OF THE METHOD ===
        print("--- [RichTextCoordinator] textView(_:clickedOnLink:at:) CALLED ---")
        print("Link object raw value: '\(link)'")
        print("Link object type: \(type(of: link))")
        print("Character Index: \(charIndex)")
        // =======================================================

        var urlStringToHandle: String?

        if let url = link as? URL {
            urlStringToHandle = url.absoluteString
            print("[RichTextCoordinator] Link is URL object: \(urlStringToHandle ?? "nil")")
        } else if let str = link as? String {
            urlStringToHandle = str
            print("[RichTextCoordinator] Link is String object: \(urlStringToHandle ?? "nil")")
        } else {
            print("[RichTextCoordinator] Link is of an unexpected type.")
        }

        if let finalUrlString = urlStringToHandle, finalUrlString.starts(with: "simpletl://") {
            print("[RichTextCoordinator] Internal link identified: \(finalUrlString). Posting notification.")
            NotificationCenter.default.post(name: .navigateToInternalItem,
                                            object: nil,
                                            userInfo: ["urlString": finalUrlString])
            print("[RichTextCoordinator] Returning TRUE (internal link handled).")
            return true
        }

        if let url = link as? URL {
            if ["http", "https"].contains(url.scheme?.lowercased()) {
                print("[RichTextCoordinator] External http/https URL identified. Letting OS handle. Returning FALSE.")
                return false
            }
        } else if let str = link as? String, let urlFromString = URL(string: str) {
            if ["http", "https"].contains(urlFromString.scheme?.lowercased()) {
                print("[RichTextCoordinator] External http/https string link identified. Letting OS handle. Returning FALSE.")
                return false
            }
        }
        
        print("[RichTextCoordinator] Link not handled or not recognized. Returning FALSE.")
        return false
    }
}

struct RichTextEditorView: NSViewRepresentable {
    @Binding var rtfData: Data?
    // The coordinator is now created and managed by this struct using makeCoordinator()
    // @ObservedObject var coordinator: RichTextCoordinator // This is no longer passed in

    func makeCoordinator() -> RichTextCoordinator {
        print("[RichTextEditorView] makeCoordinator CALLED.")
        return RichTextCoordinator(rtfData: $rtfData)
    }

    func makeNSView(context: Context) -> NSScrollView {
        print("[RichTextEditorView] makeNSView CALLED.")

        let scrollView = NSTextView.scrollableTextView()
        if let nsTextView = scrollView.documentView as? NSTextView {
            
            // Use the coordinator from the context
            nsTextView.delegate = context.coordinator
            context.coordinator.textView = nsTextView  // Give coordinator a reference to its textView
            
            print("[RichTextEditorView] makeNSView: Delegate for NSTextView set to: \(String(describing: nsTextView.delegate))")
            if nsTextView.delegate === context.coordinator {
                print("[RichTextEditorView] makeNSView: Confirmed NSTextView.delegate is the correct coordinator instance.")
            } else {
                print("[RichTextEditorView] makeNSView: WARNING - NSTextView.delegate is NOT correct or is nil.")
            }
            
            nsTextView.isRichText = true
            nsTextView.allowsImageEditing = false
            nsTextView.isEditable = true
            nsTextView.isSelectable = true
            nsTextView.font = NSFont.userFont(ofSize: 14)
            nsTextView.textColor = NSColor.textColor
            nsTextView.backgroundColor = NSColor.textBackgroundColor
            nsTextView.usesAdaptiveColorMappingForDarkAppearance = true
            nsTextView.isVerticallyResizable = true
            nsTextView.isHorizontallyResizable = false
            nsTextView.textContainer?.widthTracksTextView = true
            nsTextView.allowsUndo = true
            nsTextView.enabledTextCheckingTypes = NSTextCheckingAllTypes // Ensure links are checked
            
            if let data = rtfData,
               let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                print("[RichTextEditorView] makeNSView: Loading initial RTF data (length: \(data.count)).")
                nsTextView.textStorage?.setAttributedString(attributedString)
            } else {
                print("[RichTextEditorView] makeNSView: No initial RTF data or failed to create attributed string. Setting empty string.")
                nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            }
        } else {
            print("[RichTextEditorView] makeNSView: FAILED to get nsTextView from scrollView.")
        }
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // print("[RichTextEditorView] updateNSView CALLED.") // Can be noisy
        guard let nsTextView = nsView.documentView as? NSTextView,
              let textStorage = nsTextView.textStorage else { return }
        
        let isFirstResponder = nsTextView.window?.firstResponder == nsTextView

        if !isFirstResponder {
            let currentDataInTextView = nsTextView.rtf(from: NSRange(location: 0, length: nsTextView.string.count))
            if rtfData != currentDataInTextView {
                // print("[RichTextEditorView] updateNSView: External data change detected. Updating view.")
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
}
