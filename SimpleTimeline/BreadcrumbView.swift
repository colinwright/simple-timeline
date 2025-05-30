import SwiftUI

struct BreadcrumbView: View {
    let projectTitle: String
    let currentViewName: String
    let isProjectTitleClickable: Bool
    let projectHomeAction: (() -> Void)?

    init(projectTitle: String, currentViewName: String, isProjectTitleClickable: Bool = false, projectHomeAction: (() -> Void)? = nil) {
        self.projectTitle = projectTitle
        self.currentViewName = currentViewName
        self.isProjectTitleClickable = isProjectTitleClickable
        self.projectHomeAction = projectHomeAction
    }

    var body: some View {
        HStack(spacing: 0) {
            if isProjectTitleClickable, let action = projectHomeAction {
                Button(action: action) {
                    Text(projectTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .buttonStyle(.plain)
            } else {
                Text(projectTitle)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text(" / \(currentViewName)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        // NO .padding() here
    }
}
