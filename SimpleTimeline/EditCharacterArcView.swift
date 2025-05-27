import SwiftUI
import CoreData

struct EditCharacterArcView: View {
    // The arc we are editing
    @ObservedObject var arc: CharacterArcItem

    // The project this arc belongs to (passed to ensure correct context for pickers)
    // Although arc.project could be used, passing it explicitly can be clearer.
    @ObservedObject var project: ProjectItem

    // Core Data context
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // State for the arc's details, initialized from the existing arc
    @State private var arcName: String
    @State private var arcDescription: String
    
    // State for selecting associated items, initialized from the existing arc
    @State private var selectedCharacterID: UUID?
    @State private var selectedStartEventID: UUID?
    @State private var selectedPeakEventID: UUID?
    @State private var selectedEndEventID: UUID?

    // Fetch requests for characters and events in the current project
    @FetchRequest private var charactersInProject: FetchedResults<CharacterItem>
    @FetchRequest private var eventsInProject: FetchedResults<EventItem>

    init(arc: CharacterArcItem, project: ProjectItem) {
        _arc = ObservedObject(initialValue: arc)
        _project = ObservedObject(initialValue: project) // Initialize the project

        // Initialize state variables from the arc
        _arcName = State(initialValue: arc.name ?? "")
        _arcDescription = State(initialValue: arc.arcDescription ?? "")
        
        _selectedCharacterID = State(initialValue: arc.character?.id)
        _selectedStartEventID = State(initialValue: arc.startEvent?.id)
        _selectedPeakEventID = State(initialValue: arc.peakEvent?.id)
        _selectedEndEventID = State(initialValue: arc.endEvent?.id)
        
        // Fetch characters and events belonging to the arc's project
        let projectPredicate = NSPredicate(format: "project == %@", project)
        
        _charactersInProject = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        _eventsInProject = FetchRequest<EventItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \EventItem.eventDate, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Arc Details").font(.headline)) {
                    TextField("Arc Name (e.g., Redemption Arc)", text: $arcName)
                    
                    Section(header: Text("Description (Optional)")) {
                        TextEditor(text: $arcDescription)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3), width: 1)
                    }
                }

                Section(header: Text("Associations").font(.headline)) {
                    // Character Picker
                    Picker("Character", selection: $selectedCharacterID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(charactersInProject) { character in
                            Text(character.name ?? "Unnamed Character").tag(character.id as UUID?)
                        }
                    }
                    
                    // Start Event Picker
                    Picker("Start Event", selection: $selectedStartEventID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(eventsInProject) { event in
                            Text(event.title ?? "Untitled Event").tag(event.id as UUID?)
                        }
                    }
                    
                    // Peak Event Picker
                    Picker("Peak Event", selection: $selectedPeakEventID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(eventsInProject) { event in
                            Text(event.title ?? "Untitled Event").tag(event.id as UUID?)
                        }
                    }
                    
                    // End Event Picker
                    Picker("End Event", selection: $selectedEndEventID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(eventsInProject) { event in
                            Text(event.title ?? "Untitled Event").tag(event.id as UUID?)
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 480, idealWidth: 550, maxWidth: 700,
                   minHeight: 500, idealHeight: 600, maxHeight: 800)
            .navigationTitle("Edit Arc: \(arc.name ?? "")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(arcName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCharacterID == nil)
                }
            }
        }
    }

    private func findCharacter(by id: UUID?) -> CharacterItem? {
        guard let id = id else { return nil }
        return charactersInProject.first { $0.id == id }
    }

    private func findEvent(by id: UUID?) -> EventItem? {
        guard let id = id else { return nil }
        return eventsInProject.first { $0.id == id }
    }

    private func saveChanges() {
        guard let characterID = selectedCharacterID,
              let associatedCharacter = findCharacter(by: characterID) else {
            print("Error: Character not selected or not found for arc.")
            return
        }
        
        guard !arcName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Arc name cannot be empty.")
            return
        }

        withAnimation {
            arc.name = arcName.trimmingCharacters(in: .whitespacesAndNewlines)
            arc.arcDescription = arcDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            // creationDate is not changed
            
            arc.character = associatedCharacter
            // arc.project is already set and should not change typically

            arc.startEvent = findEvent(by: selectedStartEventID)
            arc.peakEvent = findEvent(by: selectedPeakEventID)
            arc.endEvent = findEvent(by: selectedEndEventID)

            if viewContext.hasChanges { // Save only if there are actual changes
                do {
                    try viewContext.save()
                } catch {
                    let nsError = error as NSError
                    print("Unresolved error saving character arc changes: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

struct EditCharacterArcView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project for Editing Arcs"
        sampleProject.id = UUID()

        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Arc Character for Edit"
        sampleCharacter.project = sampleProject
        sampleCharacter.id = UUID()

        let sampleStartEvent = EventItem(context: context)
        sampleStartEvent.title = "Initial Arc Start Event"
        sampleStartEvent.project = sampleProject
        sampleStartEvent.id = UUID()
        sampleStartEvent.eventDate = Date()

        let sampleArcToEdit = CharacterArcItem(context: context)
        sampleArcToEdit.name = "Existing Arc to Edit"
        sampleArcToEdit.arcDescription = "Some details about this arc."
        sampleArcToEdit.creationDate = Date()
        sampleArcToEdit.id = UUID()
        sampleArcToEdit.project = sampleProject
        sampleArcToEdit.character = sampleCharacter
        sampleArcToEdit.startEvent = sampleStartEvent
        
        return EditCharacterArcView(arc: sampleArcToEdit, project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
