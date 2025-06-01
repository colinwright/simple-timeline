// SimpleTimeline/RichTextEditorView.swift
// (Using default NSTextView from scrollableTextView() for now)

import SwiftUI
import AppKit
import Combine

class RichTextCoordinator: NSObject, NSTextViewDelegate {
    @Binding var rtfData: Data?
    weak var textView: NSTextView?
    var proxy: RichTextActionProxy

    init(rtfData: Binding<Data?>, proxy: RichTextActionProxy) {
        self._rtfData = rtfData
        self.proxy = proxy
        super.init()
        self.proxy.coordinator = self
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView.isEditable else { return }
        let contentRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        let newDataFromTextView = textView.rtf(from: contentRange)
        DispatchQueue.main.async {
            self.updateBinding(with: newDataFromTextView, from: textView)
        }
    }
    
    private func forceUpdateBindingAfterStyleChange() {
        guard let textView = self.textView else { return }
        let contentRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        let currentDataFromTextView = textView.rtf(from: contentRange)
        DispatchQueue.main.async {
            self.updateBinding(with: currentDataFromTextView, from: textView)
        }
    }

    private func updateBinding(with newDataFromTextView: Data?, from textView: NSTextView) {
        if let newData = newDataFromTextView {
            if self.rtfData != newData {
                self.rtfData = newData
            }
        } else {
            if textView.string.isEmpty {
                if self.rtfData != nil {
                    self.rtfData = nil
                }
            }
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let textStorage = textView.textStorage else {
            if self.proxy.isLinkSelected {
                DispatchQueue.main.async { self.proxy.isLinkSelected = false }
            }
            return
        }
        let currentSelectedRange = textView.selectedRange()
        var isLinkCurrentlySelected = false
        if textStorage.length > 0 {
            var effectiveLocationToCheck = currentSelectedRange.location
            if currentSelectedRange.location == textStorage.length && currentSelectedRange.length == 0 {
                if textStorage.length > 0 { effectiveLocationToCheck = currentSelectedRange.location - 1 }
                else { effectiveLocationToCheck = NSNotFound }
            }
            if effectiveLocationToCheck < textStorage.length && effectiveLocationToCheck != NSNotFound {
                if textStorage.attribute(.link, at: effectiveLocationToCheck, effectiveRange: nil) != nil {
                    isLinkCurrentlySelected = true
                }
            }
        }
        if self.proxy.isLinkSelected != isLinkCurrentlySelected {
            DispatchQueue.main.async { self.proxy.isLinkSelected = isLinkCurrentlySelected }
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if !textView.isEditable { // This delegate is primarily for non-editable views
            var urlStringToHandle: String?
            if let url = link as? URL { urlStringToHandle = url.absoluteString }
            else if let str = link as? String { urlStringToHandle = str }
            if let finalUrlString = urlStringToHandle, finalUrlString.starts(with: "simpletl://") {
                NotificationCenter.default.post(name: .navigateToInternalItem, object: nil, userInfo: ["urlString": finalUrlString])
                return true
            }
        }
        return false // Let AppKit handle external links
    }
    
    func toggleBold() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange(); let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont; let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize); let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.bold) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
        if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) } else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }; forceUpdateBindingAfterStyleChange()
    }
    func toggleItalic() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange(); let fontToCheck: NSFont? = selectedRange.length > 0 ? textView.textStorage?.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont : textView.typingAttributes[.font] as? NSFont; let currentFont = fontToCheck ?? NSFont.systemFont(ofSize: NSFont.systemFontSize); let newFont: NSFont = currentFont.fontDescriptor.symbolicTraits.contains(.italic) ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask) : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
        if selectedRange.length > 0 { textView.textStorage?.addAttribute(.font, value: newFont, range: selectedRange) } else { var attrs = textView.typingAttributes; attrs[.font] = newFont; textView.typingAttributes = attrs }; forceUpdateBindingAfterStyleChange()
    }
    func addLink(urlString: String) {
        guard let textView = textView, textView.isEditable, textView.selectedRange().length > 0 else { return }
        updateLink(at: textView.selectedRange(), with: urlString)
    }
    func removeLink() {
        guard let textView = textView, textView.isEditable else { return }
        let selectedRange = textView.selectedRange(); if selectedRange.length > 0 || proxy.isLinkSelected {
            var effectiveRange = NSRange(); let locationForLinkCheck = (selectedRange.length == 0 && selectedRange.location > 0 && selectedRange.location == textView.textStorage?.length) ? selectedRange.location - 1 : selectedRange.location
            if let textStorageLength = textView.textStorage?.length, locationForLinkCheck < textStorageLength, textView.textStorage?.attribute(.link, at: locationForLinkCheck, longestEffectiveRange: &effectiveRange, in: NSRange(location: 0, length: textStorageLength)) != nil {
                textView.textStorage?.beginEditing(); textView.textStorage?.removeAttribute(.link, range: effectiveRange); textView.textStorage?.removeAttribute(.underlineStyle, range: effectiveRange); textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: effectiveRange); textView.textStorage?.endEditing(); forceUpdateBindingAfterStyleChange()
                DispatchQueue.main.async { self.proxy.isLinkSelected = false }
            }
        }
    }
    func updateLink(at range: NSRange, with urlString: String) {
        guard let textView = textView, textView.isEditable else { return }
        var attributes: [NSAttributedString.Key: Any] = [:]; if urlString.starts(with: "simpletl://") { attributes[.link] = urlString } else { var properURLString = urlString; if !properURLString.hasPrefix("http://") && !properURLString.hasPrefix("https://") { properURLString = "https://" + properURLString }; guard let url = URL(string: properURLString) else { return }; attributes[.link] = url }; attributes[.foregroundColor] = NSColor.linkColor; attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        textView.textStorage?.beginEditing(); textView.textStorage?.addAttributes(attributes, range: range); textView.textStorage?.endEditing(); forceUpdateBindingAfterStyleChange()
    }
    func getSelectedString() -> String? {
        guard let textView = textView, textView.selectedRange().length > 0 else { return nil }
        return (textView.string as NSString).substring(with: textView.selectedRange())
    }
}

struct RichTextEditorView: NSViewRepresentable {
    @Binding var rtfData: Data?
    @ObservedObject var proxy: RichTextActionProxy
    var isEditable: Bool

    init(rtfData: Binding<Data?>, proxy: RichTextActionProxy, isEditable: Bool = true) {
        self._rtfData = rtfData
        self.proxy = proxy
        self.isEditable = isEditable
    }

    func makeCoordinator() -> RichTextCoordinator {
        return RichTextCoordinator(rtfData: $rtfData, proxy: proxy)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let nsTextView = scrollView.documentView as? NSTextView else {
            fatalError("NSTextView.scrollableTextView() did not return an NSTextView.")
        }
        context.coordinator.textView = nsTextView
        nsTextView.delegate = context.coordinator
        
        nsTextView.isRichText = true; nsTextView.isSelectable = true; nsTextView.allowsUndo = true
        nsTextView.enabledTextCheckingTypes = NSTextCheckingAllTypes; nsTextView.isEditable = self.isEditable
        nsTextView.drawsBackground = self.isEditable
        nsTextView.backgroundColor = self.isEditable ? NSColor.textBackgroundColor : .clear
        nsTextView.font = NSFont.userFont(ofSize: 14); nsTextView.textColor = NSColor.textColor
        nsTextView.isVerticallyResizable = true; nsTextView.isHorizontallyResizable = false
        nsTextView.textContainer?.widthTracksTextView = true
        
        if let data = self.rtfData, let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
            nsTextView.textStorage?.setAttributedString(attributedString)
        } else {
            nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        }
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let nsTextView = nsView.documentView as? NSTextView else { return }

        if nsTextView.isEditable != self.isEditable {
            nsTextView.isEditable = self.isEditable
            nsTextView.drawsBackground = self.isEditable
            nsTextView.backgroundColor = self.isEditable ? NSColor.textBackgroundColor : .clear
        }
        
        if !self.isEditable || !nsTextView.isFirstResponder {
            let currentDataInTextViewOnScreen: Data?
            if nsTextView.string.isEmpty {
                currentDataInTextViewOnScreen = Data()
            } else {
                // Corrected to use textStorage.length
                currentDataInTextViewOnScreen = nsTextView.rtf(from: NSRange(location: 0, length: nsTextView.textStorage?.length ?? 0))
            }
            let rtfDataFromBinding = self.rtfData ?? Data()

            if rtfDataFromBinding != (currentDataInTextViewOnScreen ?? Data()) {
                if let data = self.rtfData, let newAttributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                    nsTextView.textStorage?.setAttributedString(newAttributedString)
                } else {
                    nsTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
                }
            }
        }
    }
}

extension NSTextView {
    var isFirstResponder: Bool { return self.window?.firstResponder == self }
}
