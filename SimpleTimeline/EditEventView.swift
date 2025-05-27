import SwiftUI
import CoreData

struct EditEventView: View {
    // 1. The event we are editing
    @ObservedObject var event: EventItem

    // 2. Core Data context
    @Environment(\.managedObjectContext) private var viewContext

    // 3. Dismiss action for the sheet
    @Environment(\.dismiss) var dismiss

    // 4. State variables, initialized with the event's current details
    @State private var eventTitle: String
    @State private var eventDate: Date
    @State private var eventDescription: String
    @State private var durationDays: Int // Will be initialized from event.durationDays

    // 5. Fetch characters for the current project to select participants
    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>
    
    // 6. State to hold the set of selected character IDs for this event
    @State private var selectedCharacterIDs: Set<UUID>

    // Initializer to load event data and set up character selection
    init(event: EventItem) {
        _event = ObservedObject(initialValue: event)
        _eventTitle = State(initialValue: event.title ?? "")
        _eventDate = State(initialValue: event.eventDate ?? Date())
        _eventDescription = State(initialValue: event.eventDescription ?? "")
        // Initialize duration directly from the event's value (can be 0)
        _durationDays = State(initialValue: Int(event.durationDays))


        // Fetch characters belonging to the event's project
        let projectPredicate: NSPredicate
        if let project = event.project {
            projectPredicate = NSPredicate(format: "project == %@", project)
        } else {
            // Fallback if event somehow has no project (should not happen with current model)
            print("Warning: Event being edited has no associated project. Character list will be empty.")
            projectPredicate = NSPredicate(format: "FALSEPREDICATE")
        }
        
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        // Initialize selectedCharacterIDs with characters already participating in the event
        var initialSelectedIDs = Set<UUID>()
        if let participating = event.participatingCharacters as? Set<CharacterItem> {
            for character in participating {
                if let charID = character.id {
                    initialSelectedIDs.insert(charID)
                }
            }
        }
        _selectedCharacterIDs = State(initialValue: initialSelectedIDs)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details").font(.headline)) {
                    TextField("Event Title", text: $eventTitle)
                    DatePicker("Event Date", selection: $eventDate)
                    
                    // Stepper for duration in days, now starting from 0
                    Stepper("Duration: \(durationDays) day(s)", value: $durationDays, in: 0...365)

                    Section(header: Text("Description (Optional)")) {
                        TextEditor(text: $eventDescription)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3), width: 1)
                    }
                }
                
                // Section for selecting participating characters
                if !projectCharacters.isEmpty {
                    Section(header: Text("Participating Characters").font(.headline)) {
                        List(projectCharacters, id: \.self) { character in
                            HStack {
                                Text(character.name ?? "Unnamed Character")
                                if let hex = character.colorHex, let color = Color(hex: hex) {
                                    Circle().fill(color).frame(width: 8, height: 8)
                                }
                                Spacer()
                                if selectedCharacterIDs.contains(character.id!) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleCharacterSelection(character)
                            }
                        }
                        // Optional: Limit height if character list can be very long
                        // .frame(maxHeight: 250)
                    }
                } else {
                     Section(header: Text("Participating Characters").font(.headline)) {
                        let projectHasCharacters = (event.project?.characters as? Set<CharacterItem>)?.isEmpty == false
                        Text(projectHasCharacters ? "No characters currently selected for this event." : "No characters in this project. Add characters in the 'Characters' tab first.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding() // Add padding around the Form
            .navigationTitle("Edit Event: \(event.title ?? "")")
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
                    .disabled(eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        // Apply a frame to the NavigationView, which is the root content of the sheet
        .frame(minWidth: 480, idealWidth: 550, maxWidth: 700,
               minHeight: 450, idealHeight: 600, maxHeight: 750)
    }

    private func toggleCharacterSelection(_ character: CharacterItem) {
        guard let characterID = character.id else { return }
        if selectedCharacterIDs.contains(characterID) {
            selectedCharacterIDs.remove(characterID)
        } else {
            selectedCharacterIDs.insert(characterID)
        }
    }

    private func saveChanges() {
        withAnimation {
            event.title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            event.eventDate = eventDate
            event.eventDescription = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            event.durationDays = Int16(durationDays) // Save duration (can be 0)

            // Update participating characters
            let selectedChars = projectCharacters.filter { selectedCharacterIDs.contains($0.id!) }
            event.participatingCharacters = NSSet(array: selectedChars)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving event changes: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct EditEventView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project for Event Edit"
        sampleProject.id = UUID()

        let char1 = CharacterItem(context: context)
        char1.id = UUID()
        char1.name = "Alice (Editor)"
        char1.colorHex = "#FF00AA"
        char1.project = sampleProject
        
        let char2 = CharacterItem(context: context)
        char2.id = UUID()
        char2.name = "Bob (Editor)"
        char2.colorHex = "#00FFAA"
        char2.project = sampleProject

        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Event to Edit"
        sampleEvent.eventDate = Date()
        sampleEvent.durationDays = 0 // Example of a 0-day event for preview
        sampleEvent.project = sampleProject
        sampleEvent.participatingCharacters = NSSet(array: [char1])

        return EditEventView(event: sampleEvent)
            .environment(\.managedObjectContext, context)
    }
}
