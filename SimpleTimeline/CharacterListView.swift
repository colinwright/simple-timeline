// CharacterListView.swift

import SwiftUI
import CoreData

struct CharacterListView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selection: MainViewSelection // For main breadcrumb navigation

    @FetchRequest private var characters: FetchedResults<CharacterItem>

    @State private var selectedCharacter: CharacterItem?
    @State private var showingAddCharacterView = false
    @State private var isCharacterListVisible: Bool = true

    private let listHeaderHeight: CGFloat = 30 + (2 * 4) // Consistent with WikiView

    // --- Binding to receive navigation request from ContentView ---
    @Binding var itemIDToSelectOnAppear: UUID?
    // -----------------------------------------------------------

    init(project: ProjectItem, selection: Binding<MainViewSelection>, itemIDToSelectOnAppear: Binding<UUID?>) {
        _project = ObservedObject(initialValue: project)
        self._selection = selection
        self._itemIDToSelectOnAppear = itemIDToSelectOnAppear

        _characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Characters",
                    isProjectTitleClickable: true,
                    projectHomeAction: { selection = .projectHome }
                )
            } trailing: {
                Button {
                    showingAddCharacterView = true
                } label: {
                    Label("Add Character", systemImage: "person.fill.badge.plus")
                }
            }

            HStack(spacing: 0) {
                // Master Pane: Character List (Collapsible)
                if isCharacterListVisible {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Characters")
                                .font(.title3)
                                .padding(.leading)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCharacterListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.left.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing)
                        }
                        .frame(height: listHeaderHeight)
                        
                        Divider()
                        
                        List {
                            ForEach(characters) { character in
                                HStack {
                                    if let hex = character.colorHex, let color = Color(hex: hex) {
                                        Circle().fill(color).frame(width: 10, height: 10)
                                    }
                                    Text(character.name ?? "Unnamed Character")
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedCharacter == character ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCharacter = character
                                }
                            }
                            .onDelete(perform: deleteCharacters)
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(width: 240)
                    .transition(.move(edge: .leading))
                    Divider()
                }

                // Detail Pane
                VStack(alignment: .leading, spacing: 0) {
                     if !isCharacterListVisible {
                         HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCharacterListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.right.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading)
                            Spacer()
                        }
                        .frame(height: listHeaderHeight) // Match master pane header height
                        .animation(.easeInOut(duration: 0.2), value: isCharacterListVisible)
                    } else if characters.isEmpty && selectedCharacter == nil && isCharacterListVisible {
                         // If list is visible but empty, maintain header height for alignment
                         Color.clear.frame(height: listHeaderHeight)
                    }

                    Group {
                        if let char = selectedCharacter {
                            EditCharacterView(character: char)
                                .id(char.id) // Important for view refresh when selection changes
                        } else {
                            VStack { // Placeholder when no character is selected
                                Spacer()
                                Text(characters.isEmpty ? "No characters yet." : "Select a character to view details.")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                if characters.isEmpty {
                                    Text("Click 'Add Character' in the header to start.")
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
        .sheet(isPresented: $showingAddCharacterView) {
            AddCharacterView(project: project)
        }
        .task(id: itemIDToSelectOnAppear) { // Use .task to react to ID changes
            guard let charID = itemIDToSelectOnAppear else { return }

            if let charToSelect = characters.first(where: { $0.id == charID }) {
                selectedCharacter = charToSelect
                print("CharacterListView: Programmatically selected character via .task: \(charToSelect.name ?? "Untitled")")
            } else {
                print("CharacterListView: Character with ID \(charID) not found via .task. Characters count: \(characters.count)")
            }
            if self.itemIDToSelectOnAppear == charID { // Prevent race conditions
                self.itemIDToSelectOnAppear = nil
            }
        }
        .onChange(of: selectedCharacter) { oldValue, newValue in
            // print("Selected character changed to: \(newValue?.name ?? "None")")
        }
    }
    
    private func deleteCharacters(offsets: IndexSet) {
        withAnimation {
            offsets.map { characters[$0] }.forEach { characterToDelete in
                if selectedCharacter == characterToDelete {
                    selectedCharacter = nil
                }
                viewContext.delete(characterToDelete)
            }
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error deleting characters: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct CharacterListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.id = UUID()
        sampleProject.title = "Sample Project for Characters"
        sampleProject.creationDate = Date()

        let char1 = CharacterItem(context: context)
        char1.id = UUID(); char1.name = "Alice the Brave"; char1.colorHex = "#FF0000"
        char1.project = sampleProject; char1.creationDate = Date()
        let desc1 = NSAttributedString(string: "Alice is a brave warrior from the northern hills.")
        char1.descriptionRTFData = try? desc1.data(from: .init(location: 0, length: desc1.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        let char2 = CharacterItem(context: context)
        char2.id = UUID(); char2.name = "Bob the Wise"; char2.colorHex = "#00FF00"
        char2.project = sampleProject; char2.creationDate = Date()
        let desc2 = NSAttributedString(string: "Bob is a wise old mage, known for his cryptic advice.")
        char2.descriptionRTFData = try? desc2.data(from: .init(location: 0, length: desc2.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        
        do { try context.save() } catch {
            let nsError = error as NSError
            print("Preview save error: \(nsError), \(nsError.userInfo)")
        }

        return CharacterListView(project: sampleProject,
                                 selection: .constant(.characters),
                                 itemIDToSelectOnAppear: .constant(nil))
            .environment(\.managedObjectContext, context)
            .frame(width: 900, height: 700)
    }
}
