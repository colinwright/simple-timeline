import SwiftUI
import CoreData // Ensure CoreData is imported if not already

struct WikiPageDetailView: View {
    @ObservedObject var page: WikiPageItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text(page.title ?? "Untitled Page")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                
                Divider()
                
                Text(page.content ?? "No content for this page.")
                    .font(.body)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                
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
        
        // Create and configure the sample page within a closure
        let samplePage: WikiPageItem = {
            let page = WikiPageItem(context: context)
            page.id = UUID()
            page.title = "My Awesome Wiki Page"
            page.content = "This is some detailed content for the wiki page, explaining many interesting things about the world. It could be quite long and should scroll nicely."
            page.creationDate = Date()
            page.lastModifiedDate = Date()
            
            // If WikiPageItem has a 'project' relationship that's non-optional,
            // you'd need to set that too for the preview to be valid.
            // Example:
            // let sampleProject = ProjectItem(context: context)
            // sampleProject.title = "Preview Project"
            // page.project = sampleProject
            
            return page
        }() // Note the () to execute the closure

        return NavigationView { // Using NavigationView for preview context
            WikiPageDetailView(page: samplePage)
        }
        .environment(\.managedObjectContext, context) // Ensure context is in environment
    }
}
