import SwiftUI
import CoreData

struct CharacterListView: View {
    // The project this view is for
    @ObservedObject var project: ProjectItem

    // Core Data context
    @Environment(\.managedObjectContext) private var viewContext

    // FetchRequest for characters of the current project
    @FetchRequest private var characters: FetchedResults<CharacterItem>

    // State for presenting AddCharacterView sheet
    @State private var showingAddCharacterView = false
    // State for presenting EditCharacterView sheet
    @State private var characterToEdit: CharacterItem?
    
    // State to track expanded character descriptions by their ID
    @State private var expandedCharacterIDs: Set<UUID> = []

    // Initializer to set up the FetchRequest with a predicate for the specific project
    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project) // Initialize @ObservedObject
        
        // Initialize the FetchRequest to filter characters by the current project
        _characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Characters in: \(project.title ?? "Untitled Project")")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddCharacterView = true
                } label: {
                    Label("Add Character", systemImage: "person.crop.circle.fill.badge.plus")
                }
            }
            .padding(.bottom)

            if characters.isEmpty {
                Text("No characters yet. Click the '+' button to add one.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(characters) { character in
                        HStack(alignment: .top) { // Align items to the top for consistent button placement
                            VStack(alignment: .leading) {
                                HStack { // HStack for name and color indicator
                                    Text(character.name ?? "Unnamed Character")
                                        .font(.body)
                                    if let hex = character.colorHex, let color = Color(hex: hex) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                if let desc = character.characterDescription, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(expandedCharacterIDs.contains(character.id!) ? nil : 1) // Expandable
                                }
                            }
                            Spacer() // Pushes action buttons to the right

                            // Group expander and actions menu in their own HStack
                            HStack(spacing: 8) {
                                // Expander Button for description
                                if let desc = character.characterDescription, !desc.isEmpty {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            toggleExpansion(for: character)
                                        }
                                    } label: {
                                        Image(systemName: expandedCharacterIDs.contains(character.id!) ? "chevron.up" : "chevron.down")
                                            .imageScale(.small)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Action menu (Edit/Delete)
                                Menu {
                                    Button {
                                        characterToEdit = character // Set the character to edit
                                    } label: {
                                        Label("Edit Character", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deleteCharacter(character)
                                    } label: {
                                        Label("Delete Character", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                         .imageScale(.medium)
                                         .foregroundColor(.primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 28, height: 28, alignment: .center)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                             Button {
                                characterToEdit = character // Set the character to edit
                            } label: {
                                Label("Edit Character", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteCharacter(character)
                            } label: {
                                Label("Delete Character", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteCharactersFromOffsets)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddCharacterView) {
            AddCharacterView(project: project)
        }
        .sheet(item: $characterToEdit) { characterToEdit in
            // Present the EditCharacterView
            EditCharacterView(character: characterToEdit)
        }
    }

    private func toggleExpansion(for character: CharacterItem) {
        guard let characterID = character.id else { return }
        if expandedCharacterIDs.contains(characterID) {
            expandedCharacterIDs.remove(characterID)
        } else {
            expandedCharacterIDs.insert(characterID)
        }
    }

    private func deleteCharactersFromOffsets(offsets: IndexSet) {
        withAnimation {
            offsets.map { characters[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func deleteCharacter(_ character: CharacterItem) {
        withAnimation {
            viewContext.delete(character)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error saving context for characters: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct CharacterListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project for Characters"
        sampleProject.creationDate = Date()
        sampleProject.id = UUID()
        
        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Hero Character"
        sampleCharacter.characterDescription = "The main protagonist with a description long enough to test the expander functionality and see if it wraps correctly."
        sampleCharacter.creationDate = Date()
        sampleCharacter.id = UUID()
        sampleCharacter.colorHex = "#FF0000" // Red for preview
        sampleCharacter.project = sampleProject // Associate with the project

        return CharacterListView(project: sampleProject)
            .environment(\.managedObjectContext, context)
            .frame(width: 400, height: 500)
    }
}
