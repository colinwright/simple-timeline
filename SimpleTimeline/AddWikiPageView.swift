// AddWikiPageView.swift

import SwiftUI
import CoreData

struct AddWikiPageView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var pageTitle: String = ""
    @State private var pageContent: String = "" // This is for plain text input initially

    var body: some View {
        NavigationView { // For title and toolbar
            Form {
                Section(header: Text("Page Details")) {
                    TextField("Page Title", text: $pageTitle)
                } // Removed extra brace here that might have been a typo in original
                
                Section(header: Text("Page Content")) {
                    TextEditor(text: $pageContent) // User types plain text here
                        .frame(minHeight: 200, maxHeight: .infinity, alignment: .topLeading)
                        .border(Color.gray.opacity(0.2))
                        .lineSpacing(5)
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
            
            // Convert the plain String 'pageContent' to basic RTF Data
            // For newly created pages, the content starts as plain text.
            // If you want it to be rich text from the start, this TextEditor would need to be
            // replaced with your RichTextEditorView, but that's more complex for an "Add" screen.
            // For now, we save the initial plain text as basic RTF.
            let plainTextAttributedString = NSAttributedString(string: pageContent)
            do {
                let rtfData = try plainTextAttributedString.data(from: .init(location: 0, length: plainTextAttributedString.length),
                                                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                newPage.contentRTFData = rtfData
            } catch {
                print("Error converting plain text to RTF data: \(error)")
                // Handle error appropriately, maybe save as nil or plain string in a fallback field if you had one.
                // For now, contentRTFData might remain nil if conversion fails.
            }
            
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

// Preview (ensure it works with the changes if you rely on it)
struct AddWikiPageView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project for Wiki"
        
        return AddWikiPageView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
