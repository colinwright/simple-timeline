// WikiView.swift

import SwiftUI
import CoreData

struct WikiView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selection: MainViewSelection // For main breadcrumb navigation
    @Environment(\.managedObjectContext) private var viewContext

    // FetchRequest for WikiPageItems belonging to the current project
    @FetchRequest private var wikiPages: FetchedResults<WikiPageItem>

    @State private var selectedWikiPage: WikiPageItem?
    @State private var showingAddWikiPageView = false
    @State private var isPageListVisible: Bool = true // To control master pane visibility

    // Consistent height for the list header (like in CharacterListView)
    private let listHeaderHeight: CGFloat = 30 + (2 * 4)

    init(project: ProjectItem, selection: Binding<MainViewSelection>) {
        self.project = project
        self._selection = selection
        
        // Initialize FetchRequest
        _wikiPages = FetchRequest<WikiPageItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \WikiPageItem.creationDate, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { // Root VStack
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Wiki",
                    isProjectTitleClickable: true,
                    projectHomeAction: { selection = .projectHome } // Navigate to project home
                )
            } trailing: {
                Button {
                    showingAddWikiPageView = true
                } label: {
                    Label("Create New Page", systemImage: "plus.circle.fill")
                }
            }

            HStack(spacing: 0) { // Master-Detail layout
                // Master Pane: Page List (Collapsible)
                if isPageListVisible {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Pages")
                                .font(.title3)
                                .padding(.leading)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPageListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.left.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing)
                        }
                        .frame(height: listHeaderHeight) // Use defined constant
                        // .padding(.vertical, 4) // Included in listHeaderHeight
                        
                        Divider()
                        
                        List { // Removed selection binding for manual tap handling
                            ForEach(wikiPages) { page in
                                HStack {
                                    Text(page.title ?? "Untitled Page")
                                    Spacer()
                                    // Optionally, add an icon or indicator here
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedWikiPage == page ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedWikiPage = page
                                }
                            }
                            .onDelete(perform: deleteWikiPages)
                        }
                        .listStyle(.sidebar) // Standard sidebar list style
                    }
                    .frame(width: 240) // Typical master pane width
                    .transition(.move(edge: .leading)) // Animation for collapse/expand
                    Divider() // Visual separator
                }

                // Detail Pane: EditWikiPageView or placeholder
                VStack(alignment: .leading, spacing: 0) {
                    // Button to re-show the list if it's hidden
                    if !isPageListVisible {
                         HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPageListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.right.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading)
                            Spacer()
                        }
                        .frame(height: listHeaderHeight)
                        .animation(.easeInOut(duration: 0.2), value: isPageListVisible)
                    } else if wikiPages.isEmpty && selectedWikiPage == nil {
                        // Ensure there's some space if the list is visible but empty and no page is selected
                        // This might be redundant if the Group below handles all cases.
                        Spacer().frame(height: listHeaderHeight)
                    }


                    Group {
                        if let page = selectedWikiPage {
                            // EditWikiPageView is already designed to handle rich text
                            EditWikiPageView(page: page)
                                .id(page.id) // Ensures view redraws if page identity changes
                        } else {
                            VStack {
                                Spacer()
                                Text(wikiPages.isEmpty ? "No wiki pages yet." : "Select a page to view its content.")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                if wikiPages.isEmpty {
                                    Text("Click 'Create New Page' in the header to start.")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Detail pane fills available space
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddWikiPageView) {
            // AddWikiPageView should also be updated to save contentRTFData
            AddWikiPageView(project: project)
        }
        .onChange(of: selectedWikiPage) { oldValue, newValue in
            // print("DEBUG (WikiView onChange): selectedWikiPage changed from '\(oldValue?.title ?? "None")' to '\(newValue?.title ?? "None")'")
        }
    }
    
    private func deleteWikiPages(offsets: IndexSet) {
        withAnimation {
            offsets.map { wikiPages[$0] }.forEach { pageToDelete in
                if selectedWikiPage == pageToDelete {
                    selectedWikiPage = nil // Deselect if the current page is deleted
                }
                viewContext.delete(pageToDelete)
            }
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                // In a real app, handle this error more gracefully
                fatalError("Unresolved error deleting wiki pages: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct WikiView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Epic Fantasy World"
        sampleProject.id = UUID() // Ensure project has an ID if needed for predicates
        sampleProject.creationDate = Date()
        
        // --- Page 1 ---
        let page1 = WikiPageItem(context: context)
        page1.id = UUID()
        page1.title = "Kingdom of Eldoria"
        let page1ContentString = "Details about **Eldoria**, a vast kingdom known for its _towering spires_ and ancient magic. It is ruled by the benevolent Queen Annelise."
        // Convert plain string to basic RTF Data for the preview
        if let page1AttributedString = try? NSAttributedString(markdown: page1ContentString) { // Using markdown for simple rich text
             if let rtfData = try? page1AttributedString.data(from: .init(location: 0, length: page1AttributedString.length),
                                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                page1.contentRTFData = rtfData // Use the new attribute
            }
        } else { // Fallback for plain string if markdown fails or is not desired for simple text
            let plainAttrString = NSAttributedString(string: page1ContentString)
            if let rtfData = try? plainAttrString.data(from: .init(location: 0, length: plainAttrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                 page1.contentRTFData = rtfData
            }
        }
        page1.project = sampleProject
        page1.creationDate = Date()
        page1.lastModifiedDate = Date()

        // --- Page 2 ---
        let page2 = WikiPageItem(context: context)
        page2.id = UUID()
        page2.title = "The Shadow Isles"
        let page2ContentString = "Mysteries of the *Shadow Isles*, a place shrouded in mist and whispered legends. Few who venture there return, and those who do are changed. Visit [Example](https://www.example.com)."
        if let page2AttributedString = try? NSAttributedString(markdown: page2ContentString) {
            if let rtfData = try? page2AttributedString.data(from: .init(location: 0, length: page2AttributedString.length),
                                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                page2.contentRTFData = rtfData // Use the new attribute
            }
        } else {
            let plainAttrString = NSAttributedString(string: page2ContentString)
            if let rtfData = try? plainAttrString.data(from: .init(location: 0, length: plainAttrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                 page2.contentRTFData = rtfData
            }
        }
        page2.project = sampleProject
        page2.creationDate = Date(timeIntervalSinceNow: 60)
        page2.lastModifiedDate = Date(timeIntervalSinceNow: 60)

        // Save the preview context to ensure data is available for fetch requests
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved preview context save error \(nsError), \(nsError.userInfo)")
        }

        return WikiView(project: sampleProject, selection: .constant(.wiki))
            .environment(\.managedObjectContext, context)
            .frame(width: 900, height: 700)
    }
}
