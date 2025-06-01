// RichTextEditorView.swift

import SwiftUI
import AppKit

class RichTextCoordinator: NSObject, NSTextViewDelegate, ObservableObject {
    @Binding var rtfData: Data?
    weak var textView: NSTextView?

    init(rtfData: Binding<Data?>) {
        self._rtfData = rtfData
        super.init()
        // This print is fine
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView.isEditable else { return }
        let contentRange = NSRange(location: 0, length: textView.string.count)
        let newData = textView.rtf(from: contentRange)
        self.rtfData = newData
    }
    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        // This method is working correctly when the delegate is called.
        var urlStringToHandle: String?
        if let url = link as? URL { urlStringToHandle = url.absoluteString }
        else if let str = link as? String { urlStringToHandle = str }

        if let finalUrlString = urlStringToHandle, finalUrlString.starts(with: "simpletl://") {
            NotificationCenter.default.post(name: .navigateToInternalItem, object: nil, userInfo: ["urlString": finalUrlString])
            return true
        }
        return false
    }
    
    private func forceUpdateBindingAfterStyleChange() { guard let textView = textView else { return }; let contentRange = NSRange(location: 0, length: textView.string.count); let currentDataFromTextView = textView.rtf(from: contentRange); self.rtfData = currentDataFromTextView }
    func toggleBold() { guard let textView = textView, textView.isEditable else { return }; let selectedRange = textView.selectedRange(); let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont; let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize); let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.bold) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask); if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) } else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }; forceUpdateBindingAfterStyleChange() }
    func toggleItalic() { guard let textView = textView, textView.isEditable else { return }; let selectedRange = textView.selectedRange(); let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont; let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize); let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.italic) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask); if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) } else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }; forceUpdateBindingAfterStyleChange() }
    func addLink(urlString: String) { guard let textView = textView, textView.isEditable else { return }; let selectedRange = textView.selectedRange(); if selectedRange.length > 0 { var attributes: [NSAttributedString.Key: Any] = [:]; if urlString.starts(with: "simpletl://") { attributes[.link] = urlString } else { var properURLString = urlString; if !properURLString.hasPrefix("http://") && !properURLString.hasPrefix("https://") { properURLString = "https://" + properURLString }; guard let url = URL(string: properURLString) else { let alert = NSAlert(); alert.messageText = "Invalid URL"; alert.informativeText = "The entered URL is not valid: \(properURLString)"; alert.alertStyle = .warning; alert.addButton(withTitle: "OK"); alert.runModal(); return }; attributes[.link] = url }; attributes[.foregroundColor] = NSColor.linkColor; attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue; textView.textStorage?.beginEditing(); textView.textStorage?.addAttributes(attributes, range: selectedRange); textView.textStorage?.endEditing(); forceUpdateBindingAfterStyleChange() } else { let alert = NSAlert(); alert.messageText = "Add Link"; alert.informativeText = "Please select some text to apply the link to."; alert.alertStyle = .informational; alert.addButton(withTitle: "OK"); alert.runModal() } }
    func getSelectedString() -> String? { guard let textView = textView, textView.selectedRange().length > 0 else { return nil }; return (textView.string as NSString).substring(with: textView.selectedRange()) }
}

struct RichTextEditorView: NSViewRepresentable {
    @Binding var rtfData: Data?
    var proxy: RichTextActionProxy?
    var isEditable: Bool

    init(rtfData: Binding<Data?>, proxy: RichTextActionProxy? = nil, isEditable: Bool = true) {
        self._rtfData = rtfData
        self.proxy = proxy
        self.isEditable = isEditable
        print("[View TRACE] Init called. isEditable: \(isEditable). Data is nil: \(rtfData.wrappedValue == nil)")
    }

    func makeCoordinator() -> RichTextCoordinator {
        return RichTextCoordinator(rtfData: $rtfData)
    }

    func makeNSView(context: Context) -> NSScrollView {
        print("[View TRACE] makeNSView CALLED. isEditable: \(self.isEditable)")
        let scrollView = NSTextView.scrollableTextView()
        
        if let nsTextView = scrollView.documentView as? NSTextView {
            context.coordinator.textView = nsTextView
            proxy?.coordinator = context.coordinator
            nsTextView.delegate = context.coordinator
            
            nsTextView.isRichText = true
            nsTextView.isSelectable = true
            nsTextView.allowsUndo = true
            nsTextView.enabledTextCheckingTypes = NSTextCheckingAllTypes
            nsTextView.isEditable = self.isEditable
            nsTextView.drawsBackground = self.isEditable
            nsTextView.backgroundColor = self.isEditable ? NSColor.textBackgroundColor : .clear
            
            nsTextView.font = NSFont.userFont(ofSize: 14)
            nsTextView.textColor = NSColor.textColor
            nsTextView.isVerticallyResizable = true
            nsTextView.isHorizontallyResizable = false
            nsTextView.textContainer?.widthTracksTextView = true
            
            print("[View TRACE] makeNSView: About to set initial text. Data is nil: \(rtfData == nil), Data count: \(rtfData?.count ?? 0)")
            if let data = rtfData, !data.isEmpty { // Ensure data is not empty
                if let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                    nsTextView.textStorage?.setAttributedString(attributedString)
                    print("[View TRACE] makeNSView: SUCCESSFULLY set attributedString. Length: \(attributedString.length)")
                } else {
                    print("[View TRACE] makeNSView: FAILED to create attributedString from RTF data. Setting empty string.")
                    nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
                }
            } else {
                print("[View TRACE] makeNSView: rtfData is nil or empty. Setting empty string.")
                nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            }
            print("[View TRACE] makeNSView: NSTextView content length after set: \(nsTextView.string.count)")

        } else {
            print("[View TRACE] makeNSView: FAILED to get nsTextView from scrollView.")
        }
        
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        print("[View TRACE] updateNSView CALLED. isEditable: \(self.isEditable)")
        guard let nsTextView = nsView.documentView as? NSTextView else { return }
        
        // Only update if not first responder OR if it's a read-only view (which should always reflect the binding)
        if !nsTextView.isFirstResponder || !self.isEditable {
            print("[View TRACE] updateNSView: Condition met to update. Data is nil: \(rtfData == nil), Data count: \(rtfData?.count ?? 0)")
            
            let currentDataInTextView: Data?
            if nsTextView.string.isEmpty {
                currentDataInTextView = Data() // Represent empty as empty Data for comparison
            } else {
                currentDataInTextView = nsTextView.rtf(from: NSRange(location: 0, length: nsTextView.string.count))
            }

            // Compare, ensuring both optionals are handled
            let rtfDataForComparison = rtfData ?? Data() // Treat nil binding as empty Data

            if rtfDataForComparison != (currentDataInTextView ?? Data()) {
                print("[View TRACE] updateNSView: Data mismatch. Updating view.")
                if let data = rtfData, !data.isEmpty { // Ensure data is not empty
                    if let newString = NSAttributedString(rtf: data, documentAttributes: nil) {
                        nsTextView.textStorage?.setAttributedString(newString)
                        print("[View TRACE] updateNSView: SUCCESSFULLY updated attributedString. Length: \(newString.length)")
                    } else {
                        print("[View TRACE] updateNSView: FAILED to create attributedString from RTF data on update. Setting empty string.")
                        nsTextView.textStorage?.setAttributedString(NSAttributedString(string:""))
                    }
                } else {
                     print("[View TRACE] updateNSView: rtfData is nil or empty on update. Setting empty string.")
                    nsTextView.textStorage?.setAttributedString(NSAttributedString(string:""))
                }
                print("[View TRACE] updateNSView: NSTextView content length after update: \(nsTextView.string.count)")
            } else {
                print("[View TRACE] updateNSView: Data is current. No update needed.")
            }
        } else {
            print("[View TRACE] updateNSView: View is first responder AND editable. Skipping update.")
        }
    }
}

extension NSTextView {
    var isFirstResponder: Bool {
        return self.window?.firstResponder == self
    }
}
