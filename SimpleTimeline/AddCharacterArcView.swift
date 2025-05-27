import SwiftUI
import CoreData

struct AddCharacterArcView: View {
    // The project this arc will belong to
    @ObservedObject var project: ProjectItem

    // Core Data context
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // State for the new arc's details
    @State private var arcName: String = ""
    @State private var arcDescription: String = ""
    
    // State for selecting associated items
    @State private var selectedCharacterID: UUID?
    @State private var selectedStartEventID: UUID?
    @State private var selectedPeakEventID: UUID?
    @State private var selectedEndEventID: UUID?

    // Fetch requests for characters and events in the current project
    @FetchRequest private var charactersInProject: FetchedResults<CharacterItem>
    @FetchRequest private var eventsInProject: FetchedResults<EventItem>

    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
        
        let projectPredicate = NSPredicate(format: "project == %@", project)
        
        _charactersInProject = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        _eventsInProject = FetchRequest<EventItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \EventItem.eventDate, ascending: true)], // Sort events by date
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
                    Picker("Select Character", selection: $selectedCharacterID) {
                        Text("None").tag(nil as UUID?) // Option for no character selected
                        ForEach(charactersInProject) { character in
                            Text(character.name ?? "Unnamed Character").tag(character.id as UUID?)
                        }
                    }
                    
                    // Start Event Picker
                    Picker("Start Event (Optional)", selection: $selectedStartEventID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(eventsInProject) { event in
                            Text(event.title ?? "Untitled Event").tag(event.id as UUID?)
                        }
                    }
                    
                    // Peak Event Picker
                    Picker("Peak Event (Optional)", selection: $selectedPeakEventID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(eventsInProject) { event in
                            Text(event.title ?? "Untitled Event").tag(event.id as UUID?)
                        }
                    }
                    
                    // End Event Picker
                    Picker("End Event (Optional)", selection: $selectedEndEventID) {
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
            .navigationTitle("Add New Character Arc")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Arc") {
                        saveCharacterArc()
                        dismiss()
                    }
                    // Disable save if arc name or character is not set
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

    private func saveCharacterArc() {
        guard let characterID = selectedCharacterID,
              let associatedCharacter = findCharacter(by: characterID) else {
            print("Error: Character not selected or not found.")
            // Optionally, show an alert to the user
            return
        }
        
        guard !arcName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Arc name cannot be empty.")
            // Optionally, show an alert to the user
            return
        }

        withAnimation {
            let newArc = CharacterArcItem(context: viewContext)
            newArc.id = UUID()
            newArc.name = arcName.trimmingCharacters(in: .whitespacesAndNewlines)
            newArc.arcDescription = arcDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            newArc.creationDate = Date()
            
            newArc.character = associatedCharacter
            newArc.project = project // Link to the current project

            if let startEventID = selectedStartEventID {
                newArc.startEvent = findEvent(by: startEventID)
            }
            if let peakEventID = selectedPeakEventID {
                newArc.peakEvent = findEvent(by: peakEventID)
            }
            if let endEventID = selectedEndEventID {
                newArc.endEvent = findEvent(by: endEventID)
            }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving new character arc: \(nsError), \(nsError.userInfo)")
                // Consider more robust error handling for the user
            }
        }
    }
}

struct AddCharacterArcView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project for Arcs"
        sampleProject.id = UUID()

        // Add a sample character to the project for the preview
        let sampleChar = CharacterItem(context: context)
        sampleChar.id = UUID()
        sampleChar.name = "Sample Arc Character"
        sampleChar.project = sampleProject
        
        // Add a sample event
        let sampleEv = EventItem(context: context)
        sampleEv.id = UUID()
        sampleEv.title = "Sample Event for Arc"
        sampleEv.eventDate = Date()
        sampleEv.project = sampleProject


        return AddCharacterArcView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
