import SwiftUI
import CoreData

struct EditWikiPageView: View {
    @ObservedObject var page: WikiPageItem
    @Environment(\.managedObjectContext) private var viewContext

    @State private var editableTitle: String
    @State private var editableMainContent: String
    @State private var isEditingPage: Bool = false

    // Consistent style for field labels
    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.bottom, -2) // Slightly reduce space below label
    }

    init(page: WikiPageItem) {
        self.page = page
        _editableTitle = State(initialValue: page.title ?? "")
        _editableMainContent = State(initialValue: page.content ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Edit/Save button for this specific page
            HStack {
                // The page title itself is displayed below, not as part of this button bar
                Spacer()
                if isEditingPage {
                    Button("Save Page") {
                        savePageChanges()
                        isEditingPage = false
                    }
                    .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Page") {
                        // Load current values into editable state when starting to edit
                        editableTitle = page.title ?? ""
                        editableMainContent = page.content ?? ""
                        isEditingPage = true
                    }
                }
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12) // Space below button bar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) { // Spacing for content blocks
                    // Page Title
                    VStack(alignment: .leading) {
                        // "Page Title" label was removed as per your request in previous step
                        if isEditingPage {
                            TextField("", text: $editableTitle, prompt: Text("Enter page title"))
                                .font(.title)
                                .fontWeight(.bold)
                        } else {
                            Text(page.title ?? "Untitled Page")
                                .font(.title)
                                .fontWeight(.bold)
                                .textSelection(.enabled)
                        }
                    }

                    // Main Content Area
                    VStack(alignment: .leading) {
                        fieldLabel("Main Content") // This label is kept for now
                        if isEditingPage {
                            TextEditor(text: $editableMainContent)
                                .frame(minHeight: 150, idealHeight: 300, maxHeight: .infinity)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .font(.body)
                        } else {
                            Text(page.content?.isEmpty == false ? (page.content ?? "") : "(No content for this page)")
                                .textSelection(.enabled)
                                .foregroundColor(page.content?.isEmpty == false ? .primary : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: page) { _, newPage in
            if !isEditingPage {
                editableTitle = newPage.title ?? ""
                editableMainContent = newPage.content ?? ""
            }
        }
    }

    private func savePageChanges() {
        let trimmedTitle = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasChanges = false

        if !trimmedTitle.isEmpty && page.title != trimmedTitle {
            page.title = trimmedTitle
            hasChanges = true
        }
        if page.content != editableMainContent {
            page.content = editableMainContent
            hasChanges = true
        }
        
        if hasChanges {
            page.lastModifiedDate = Date()
        }

        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error saving wiki page: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct EditWikiPageView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project"

        let samplePage = WikiPageItem(context: context)
        samplePage.id = UUID()
        samplePage.title = "Sample Wiki Page Title"
        samplePage.content = "This is the main content of the wiki page. It can be multiple paragraphs and quite long."
        samplePage.creationDate = Date()
        samplePage.lastModifiedDate = Date()
        samplePage.project = sampleProject

        return EditWikiPageView(page: samplePage)
            .environment(\.managedObjectContext, context)
            .frame(width: 500, height: 700)
    }
}
