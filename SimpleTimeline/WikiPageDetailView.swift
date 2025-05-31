// WikiPageDetailView.swift

import SwiftUI
import CoreData // Ensure CoreData is imported

struct WikiPageDetailView: View {
    @ObservedObject var page: WikiPageItem

    // Helper to convert RTF Data to SwiftUI AttributedString
    private var contentAttributedString: AttributedString? {
        guard let rtfData = page.contentRTFData,
              let nsAttributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) else {
            return nil
        }
        return AttributedString(nsAttributedString)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text(page.title ?? "Untitled Page")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                
                Divider()
                
                // UPDATED: Display the rich text content
                if let attributedContent = contentAttributedString, !attributedContent.runs.isEmpty {
                    Text(attributedContent)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                } else {
                    Text("No content for this page.")
                        .font(.body)
                        .foregroundColor(.secondary) // Indicate empty content
                        .lineSpacing(5)
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WikiPageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let samplePage: WikiPageItem = {
            let page = WikiPageItem(context: context)
            page.id = UUID()
            page.title = "My Awesome Wiki Page (Rich Text)"
            
            // Create sample RTF data for the preview
            let sampleContentString = "This is some **detailed content** for the wiki page, explaining many *interesting things* about the world. It could be quite long and should scroll nicely. Here's a link: [Example](https://www.example.com)"
            let initialAttributedString = NSAttributedString(string: sampleContentString) // For simplicity, start with plain string
            
            // Convert to RTF Data for storing in contentRTFData
            // In a real scenario, this would be proper RTF from your editor
            do {
                let rtfData = try initialAttributedString.data(from: .init(location: 0, length: initialAttributedString.length),
                                                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                page.contentRTFData = rtfData // Use the new attribute
            } catch {
                print("Error creating sample RTF data for preview: \(error)")
                // page.contentRTFData will be nil, and the view should handle it
            }

            page.creationDate = Date()
            page.lastModifiedDate = Date()
            
            // If WikiPageItem has a 'project' relationship that's non-optional, set that too.
            // let sampleProject = ProjectItem(context: context)
            // sampleProject.title = "Preview Project"
            // page.project = sampleProject
            
            return page
        }()

        return NavigationView {
            WikiPageDetailView(page: samplePage)
        }
        .environment(\.managedObjectContext, context)
    }
}
