// WikiView.swift

import SwiftUI
import CoreData

struct WikiView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selection: MainViewSelection
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var wikiPages: FetchedResults<WikiPageItem>

    @State private var selectedWikiPage: WikiPageItem?
    @State private var showingAddWikiPageView = false
    @State private var isPageListVisible: Bool = true
    private let listHeaderHeight: CGFloat = 30 + (2 * 4)

    @Binding var itemIDToSelectOnAppear: UUID?

    init(project: ProjectItem, selection: Binding<MainViewSelection>, itemIDToSelectOnAppear: Binding<UUID?>) {
        self.project = project
        self._selection = selection
        self._itemIDToSelectOnAppear = itemIDToSelectOnAppear
        
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
                Button { showingAddWikiPageView = true } label: {
                    Label("Create New Page", systemImage: "plus.circle.fill")
                }
            }

            HStack(spacing: 0) {
                if isPageListVisible {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Pages").font(.title3).padding(.leading)
                            Spacer()
                            Button { withAnimation(.easeInOut(duration: 0.2)) { isPageListVisible.toggle() } } label: { Image(systemName: "chevron.left.square.fill") }
                            .buttonStyle(.borderless).padding(.trailing)
                        }.frame(height: listHeaderHeight)
                        Divider()
                        List {
                            ForEach(wikiPages) { page in
                                HStack { Text(page.title ?? "Untitled Page"); Spacer() }
                                .padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedWikiPage == page ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(4).contentShape(Rectangle())
                                .onTapGesture { selectedWikiPage = page }
                            }
                            .onDelete(perform: deleteWikiPages)
                        }.listStyle(.sidebar)
                    }
                    .frame(width: 240).transition(.move(edge: .leading))
                    Divider()
                }

                VStack(alignment: .leading, spacing: 0) {
                    if !isPageListVisible {
                         HStack {
                            Button { withAnimation(.easeInOut(duration: 0.2)) { isPageListVisible.toggle() } } label: { Image(systemName: "chevron.right.square.fill") }
                            .buttonStyle(.borderless).padding(.leading)
                            Spacer()
                        }.frame(height: listHeaderHeight).animation(.easeInOut(duration: 0.2), value: isPageListVisible)
                    } else if wikiPages.isEmpty && selectedWikiPage == nil && isPageListVisible {
                        Color.clear.frame(height: listHeaderHeight)
                    }

                    Group {
                        if let page = selectedWikiPage {
                            EditWikiPageView(page: page).id(page.id)
                        } else {
                            VStack {
                                Spacer()
                                Text(wikiPages.isEmpty ? "No wiki pages yet." : "Select a page to view its content.")
                                    .font(.title2).foregroundColor(.secondary).multilineTextAlignment(.center)
                                if wikiPages.isEmpty {
                                    Text("Click 'Create New Page' in the header to start.")
                                        .foregroundColor(.secondary).multilineTextAlignment(.center)
                                }
                                Spacer()
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddWikiPageView) { AddWikiPageView(project: project) }
        .task(id: itemIDToSelectOnAppear) {
            guard let pageID = itemIDToSelectOnAppear else { return }

            if let pageToSelect = wikiPages.first(where: { $0.id == pageID }) {
                selectedWikiPage = pageToSelect
                print("WikiView: Programmatically selected page via .task: \(pageToSelect.title ?? "Untitled")")
            } else {
                print("WikiView: Page with ID \(pageID) not found via .task. wikiPages count: \(wikiPages.count)")
            }
            if self.itemIDToSelectOnAppear == pageID {
                self.itemIDToSelectOnAppear = nil
            }
        }
        .onChange(of: selectedWikiPage) { oldValue, newValue in
            // print("DEBUG (WikiView onChange): selectedWikiPage changed from '\(oldValue?.title ?? "None")' to '\(newValue?.title ?? "None")'")
        }
    }
    
    private func deleteWikiPages(offsets: IndexSet) {
        withAnimation {
            offsets.map { wikiPages[$0] }.forEach { pageToDelete in
                if selectedWikiPage == pageToDelete { selectedWikiPage = nil }
                viewContext.delete(pageToDelete)
            }
            do { try viewContext.save() } catch {
                let nsError = error as NSError
                // Consider non-fatal error handling for production
                print("Unresolved error deleting wiki pages: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct WikiView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.id = UUID(); sampleProject.title = "Epic Fantasy World"; sampleProject.creationDate = Date()
        
        let page1 = WikiPageItem(context: context); page1.id = UUID(); page1.title = "Kingdom of Eldoria"
        let p1Content = NSAttributedString(string: "Details about **Eldoria**.")
        page1.contentRTFData = try? p1Content.data(from: .init(location: 0, length: p1Content.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        page1.project = sampleProject; page1.creationDate = Date(); page1.lastModifiedDate = Date()

        let page2 = WikiPageItem(context: context); page2.id = UUID(); page2.title = "The Shadow Isles"
        let p2Content = NSAttributedString(string: "Mysteries of the *Shadow Isles*.")
        page2.contentRTFData = try? p2Content.data(from: .init(location: 0, length: p2Content.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        page2.project = sampleProject; page2.creationDate = Date(timeIntervalSinceNow: 60); page2.lastModifiedDate = Date(timeIntervalSinceNow: 60)
        
        do { try context.save() } catch {
            let nsError = error as NSError
            print("Preview save error \(nsError), \(nsError.userInfo)")
        }

        return WikiView(project: sampleProject,
                        selection: .constant(.wiki),
                        itemIDToSelectOnAppear: .constant(nil))
            .environment(\.managedObjectContext, context)
            .frame(width: 900, height: 700)
    }
}
