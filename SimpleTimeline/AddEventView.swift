import SwiftUI
import CoreData

struct AddEventView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventDescription: String = ""
    @State private var durationDays: Int = 0

    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>
    @State private var selectedCharacterIDs: Set<UUID> = []

    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }

    var body: some View {
        // The NavigationView helps with title and toolbar items in a sheet.
        // We will control the overall sheet size via its content.
        NavigationView {
            Form {
                Section(header: Text("Event Details").font(.headline)) {
                    TextField("Event Title", text: $eventTitle)
                    DatePicker("Event Date", selection: $eventDate)
                    Stepper("Duration: \(durationDays) day(s)", value: $durationDays, in: 0...365)
                    Section(header: Text("Description (Optional)")) {
                        TextEditor(text: $eventDescription)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3), width: 1)
                    }
                }
                
                if !projectCharacters.isEmpty {
                    Section(header: Text("Participating Characters").font(.headline)) {
                        List(projectCharacters, id: \.self, selection: $selectedCharacterIDs) { character in
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
                        Text("No characters in this project to add to the event. Add characters in the 'Characters' tab first.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding() // Add padding around the Form
            .navigationTitle("Add New Event to \(project.title ?? "Project")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Event") {
                        saveEvent()
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

    private func saveEvent() {
        withAnimation {
            let newEvent = EventItem(context: viewContext)
            newEvent.id = UUID()
            newEvent.title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.eventDate = eventDate
            newEvent.eventDescription = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.durationDays = Int16(durationDays)
            newEvent.project = project

            let selectedChars = projectCharacters.filter { selectedCharacterIDs.contains($0.id!) }
            newEvent.participatingCharacters = NSSet(array: selectedChars)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving new event: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddEventView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project"
        sampleProject.id = UUID()
        sampleProject.creationDate = Date()

        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.id = UUID()
        sampleCharacter.name = "Sample Character for Event"
        sampleCharacter.project = sampleProject
        
        return AddEventView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
