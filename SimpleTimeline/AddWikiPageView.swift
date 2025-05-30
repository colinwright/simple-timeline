import SwiftUI
import CoreData

struct AddWikiPageView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var pageTitle: String = ""
    @State private var pageContent: String = "" // Simple TextEditor for content

    var body: some View {
        NavigationView { // For title and toolbar
            Form {
                Section(header: Text("Page Details")) {
                    TextField("Page Title", text: $pageTitle)
                    
                    Section(header: Text("Page Content")) {
                        TextEditor(text: $pageContent)
                            .frame(minHeight: 200, maxHeight: .infinity, alignment: .topLeading)
                            .border(Color.gray.opacity(0.2))
                            .lineSpacing(5)
                    }
                }
            }
            .padding()
            .frame(minWidth: 480, idealWidth: 600, maxWidth: 800,
                   minHeight: 400, idealHeight: 500, maxHeight: 700)
            .navigationTitle("Create New Wiki Page")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Page") {
                        saveWikiPage()
                        dismiss()
                    }
                    .disabled(pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveWikiPage() {
        withAnimation {
            let newPage = WikiPageItem(context: viewContext)
            newPage.id = UUID()
            newPage.title = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            newPage.content = pageContent
            newPage.creationDate = Date()
            newPage.lastModifiedDate = Date()
            newPage.project = project
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                // Consider more robust error handling in a production app
                fatalError("Unresolved error saving new wiki page: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddWikiPageView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project for Wiki"
        
        return AddWikiPageView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
