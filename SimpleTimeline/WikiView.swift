import SwiftUI
import CoreData

struct WikiView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selection: MainViewSelection // For main breadcrumb navigation
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var wikiPages: FetchedResults<WikiPageItem>

    @State private var selectedWikiPage: WikiPageItem?
    @State private var showingAddWikiPageView = false
    @State private var isPageListVisible: Bool = true

    private let listHeaderHeight: CGFloat = 30 + (2 * 4)

    init(project: ProjectItem, selection: Binding<MainViewSelection>) {
        self.project = project
        self._selection = selection
        
        _wikiPages = FetchRequest<WikiPageItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \WikiPageItem.creationDate, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Wiki",
                    isProjectTitleClickable: true,
                    projectHomeAction: { selection = .projectHome }
                )
            } trailing: {
                Button {
                    showingAddWikiPageView = true
                } label: {
                    Label("Create New Page", systemImage: "plus.circle.fill")
                }
            }

            HStack(spacing: 0) {
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
                        .frame(height: 30)
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        List { // Removed selection binding here for manual tap handling
                            ForEach(wikiPages) { page in
                                HStack {
                                    Text(page.title ?? "Untitled Page")
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedWikiPage == page ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // print("TAPPED on page: \(page.title ?? "None")") // For debug
                                    selectedWikiPage = page
                                }
                            }
                            .onDelete(perform: deleteWikiPages)
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(width: 240)
                    .transition(.move(edge: .leading))
                    Divider()
                }

                // Detail Pane
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if !isPageListVisible {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPageListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.right.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading)
                        }
                        Spacer()
                    }
                    .frame(height: listHeaderHeight)
                    .opacity(!isPageListVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPageListVisible)

                    Group {
                        if let page = selectedWikiPage {
                            EditWikiPageView(page: page) // This is where the selected page is shown
                                .id(page.id)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddWikiPageView) {
            AddWikiPageView(project: project)
        }
        .onChange(of: selectedWikiPage) { oldValue, newValue in
            // print("DEBUG (onChange): selectedWikiPage changed from '\(oldValue?.title ?? "None")' to '\(newValue?.title ?? "None")'")
        }
    }
    
    private func deleteWikiPages(offsets: IndexSet) {
        withAnimation {
            offsets.map { wikiPages[$0] }.forEach { pageToDelete in
                if selectedWikiPage == pageToDelete {
                    selectedWikiPage = nil
                }
                viewContext.delete(pageToDelete)
            }
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
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
        
        let page1 = WikiPageItem(context: context); page1.id = UUID(); page1.title = "Kingdom of Eldoria"; page1.content = "Details about Eldoria..."; page1.project = sampleProject; page1.creationDate = Date()
        let page2 = WikiPageItem(context: context); page2.id = UUID(); page2.title = "The Shadow Isles"; page2.content = "Mysteries of the Shadow Isles..."; page2.project = sampleProject; page2.creationDate = Date(timeIntervalSinceNow: 60)

        return WikiView(project: sampleProject, selection: .constant(.wiki))
            .environment(\.managedObjectContext, context)
            .frame(width: 900, height: 700)
    }
}
