import SwiftUI
import CoreData // Potentially needed if ReadOnlyRichTextView uses Core Data types directly, though it takes Data?

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
            // You can have slightly different placeholders if you like
            Text("(No content)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// You can add other shared helper views to this file in the future.
