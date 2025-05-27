import SwiftUI
import CoreData

struct CharacterArcListView: View {
    // The project this view is for
    @ObservedObject var project: ProjectItem

    // Core Data context
    @Environment(\.managedObjectContext) private var viewContext

    // FetchRequest for CharacterArcItems of the current project
    @FetchRequest private var characterArcs: FetchedResults<CharacterArcItem>

    // State for presenting AddCharacterArcView sheet
    @State private var showingAddCharacterArcView = false
    
    // State for presenting EditCharacterArcView sheet
    @State private var arcToEdit: CharacterArcItem? // This will trigger the .sheet(item:)

    // Initializer to set up the FetchRequest
    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
        
        // Fetch CharacterArcItems belonging to the current project
        _characterArcs = FetchRequest<CharacterArcItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterArcItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Character Arcs for: \(project.title ?? "Untitled Project")")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddCharacterArcView = true
                } label: {
                    Label("Add Arc", systemImage: "arrow.triangle.branch")
                }
            }
            .padding(.bottom)

            if characterArcs.isEmpty {
                Text("No character arcs defined for this project yet. Click the '+' button to add one.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(characterArcs) { arc in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(arc.name ?? "Unnamed Arc")
                                    .font(.body)
                                if let characterName = arc.character?.name {
                                    Text("Character: \(characterName)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                if let startEventName = arc.startEvent?.title {
                                    Text("Starts: \(startEventName)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let peakEventName = arc.peakEvent?.title {
                                    Text("Peaks: \(peakEventName)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let endEventName = arc.endEvent?.title {
                                    Text("Ends: \(endEventName)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let desc = arc.arcDescription, !desc.isEmpty {
                                    Text("Description: \(desc)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Menu {
                                Button {
                                    arcToEdit = arc // Set the arc to edit
                                } label: {
                                    Label("Edit Arc", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteArc(arc)
                                } label: {
                                    Label("Delete Arc", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                     .imageScale(.medium)
                                     .foregroundColor(.primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 28, height: 28, alignment: .center)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                             Button {
                                arcToEdit = arc // Set the arc to edit
                            } label: {
                                Label("Edit Arc", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteArc(arc)
                            } label: {
                                Label("Delete Arc", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteArcsFromOffsets)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddCharacterArcView) {
            AddCharacterArcView(project: project)
        }
        .sheet(item: $arcToEdit) { arcToEdit in
            // Present the EditCharacterArcView, passing the arc and its project
            EditCharacterArcView(arc: arcToEdit, project: self.project)
        }
    }

    private func deleteArcsFromOffsets(offsets: IndexSet) {
        withAnimation {
            offsets.map { characterArcs[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func deleteArc(_ arc: CharacterArcItem) {
        withAnimation {
            if arcToEdit == arc {
                arcToEdit = nil
            }
            viewContext.delete(arc)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error saving context for character arcs: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct CharacterArcListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project for Arcs"
        sampleProject.id = UUID()

        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Arc Character"
        sampleCharacter.project = sampleProject
        sampleCharacter.id = UUID()

        let sampleStartEvent = EventItem(context: context)
        sampleStartEvent.title = "Arc Start Event"
        sampleStartEvent.project = sampleProject
        sampleStartEvent.id = UUID()
        sampleStartEvent.eventDate = Date()

        let sampleArc = CharacterArcItem(context: context)
        sampleArc.name = "Sample Redemption Arc"
        sampleArc.arcDescription = "A test arc for preview."
        sampleArc.creationDate = Date()
        sampleArc.id = UUID()
        sampleArc.project = sampleProject
        sampleArc.character = sampleCharacter
        sampleArc.startEvent = sampleStartEvent
        
        return CharacterArcListView(project: sampleProject)
            .environment(\.managedObjectContext, context)
            .frame(width: 500, height: 600)
    }
}
