// SimpleTimeline/HelperViews.swift

import SwiftUI
import CoreData

struct ReadOnlyRichTextView: View {
    let rtfData: Data?

    var attributedString: AttributedString? {
        guard let data = rtfData,
              let nsAttrStr = NSAttributedString(rtf: data, documentAttributes: nil) else {
            return nil
        }
        return AttributedString(nsAttrStr)
    }

    var body: some View {
        if let attrString = attributedString, !attrString.runs.isEmpty {
            Text(attrString)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("(No content)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    /// Applies a modifier to a view only when a given condition is true.
    /// - Parameters:
    ///   - condition: The boolean condition to evaluate.
    ///   - transform: The closure that returns the modified view.
    /// - Returns: The original view or the modified view.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
