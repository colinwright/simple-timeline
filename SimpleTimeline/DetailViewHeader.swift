import SwiftUI

struct DetailViewHeader<LeadingContent: View, TrailingContent: View>: View {
    let leadingContent: LeadingContent
    let trailingContent: TrailingContent

    init(@ViewBuilder leading: () -> LeadingContent, @ViewBuilder trailing: () -> TrailingContent) {
        self.leadingContent = leading()
        self.trailingContent = trailing()
    }

    init(@ViewBuilder leading: () -> LeadingContent) where TrailingContent == EmptyView {
        self.init(leading: leading, trailing: { EmptyView() })
    }

    var body: some View {
        HStack {
            leadingContent
            Spacer()
            trailingContent
        }
        .padding() // Consistent padding for the entire header line
    }
}
