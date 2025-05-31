import SwiftUI
import CoreData

struct EditEventView: View {
    @ObservedObject var event: EventItem

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var eventTitle: String
    @State private var eventDate: Date
    @State private var eventType: String
    @State private var eventLocation: String
    @State private var eventSummaryLine: String
    @State private var eventDescription: String
    @State private var durationDays: Int
    @State private var eventColorHex: String

    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>
    @State private var selectedCharacterIDs: Set<UUID>

    init(event: EventItem) {
        self.event = event
        _eventTitle = State(initialValue: event.title ?? "")
        _eventDate = State(initialValue: event.eventDate ?? Date())
        _eventType = State(initialValue: event.type ?? "")
        _eventLocation = State(initialValue: event.locationName ?? "")
        _eventSummaryLine = State(initialValue: event.summaryLine ?? "")
        _eventDescription = State(initialValue: event.eventDescription ?? "")
        _durationDays = State(initialValue: Int(event.durationDays))
        _eventColorHex = State(initialValue: event.eventColorHex ?? "")

        // Ensure event.project is not nil before using in predicate
        // If event.project could be nil, you might need a more robust fallback or handling.
        // For this context, we assume event.project is valid.
        let projectForFetch = event.project!
        let projectPredicate = NSPredicate(format: "project == %@", projectForFetch)
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate, animation: .default )
        _selectedCharacterIDs = State(initialValue: Set((event.participatingCharacters as? Set<CharacterItem>)?.compactMap { $0.id } ?? []))
    }
    
    // Corrected fieldLabel function
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.bottom, -3) // Keep existing padding
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Core Event Details").font(.headline)) {
                    VStack(alignment: .leading) { fieldLabel("Title*"); TextField("Event Title", text: $eventTitle) }
                    VStack(alignment: .leading) { fieldLabel("Date*"); DatePicker("Event Date", selection: $eventDate, displayedComponents: .date).labelsHidden() }
                    VStack(alignment: .leading) { fieldLabel("Duration"); Stepper("\(durationDays) day(s)", value: $durationDays, in: 0...365) }
                }
                
                Section(header: Text("Categorization & Location").font(.headline)) {
                    VStack(alignment: .leading) { fieldLabel("Type"); TextField("Event Type (Optional)", text: $eventType) }
                    VStack(alignment: .leading) { fieldLabel("Color Hex (Optional)"); TextField("Hex Color Code", text: $eventColorHex) }
                    VStack(alignment: .leading) { fieldLabel("Location (Optional)"); TextField("Location Name", text: $eventLocation) }
                }

                Section(header: Text("Content").font(.headline)) {
                    VStack(alignment: .leading) {
                        fieldLabel("Summary Line (for timeline block display)")
                        TextField("One-line summary (Optional)", text: $eventSummaryLine, axis: .vertical).lineLimit(1...2).frame(minHeight:30)
                    }
                    VStack(alignment: .leading) {
                        fieldLabel("Full Description (Optional)")
                        TextEditor(text: $eventDescription).frame(minHeight: 80, idealHeight: 100).border(Color.gray.opacity(0.2))
                    }
                }
                
                if !projectCharacters.isEmpty {
                    Section(header: Text("Participating Characters (\(selectedCharacterIDs.count))")) {
                        List {
                            ForEach(projectCharacters) { character in
                                Button(action: { toggleCharacterSelection(character) }) {
                                    HStack {
                                        Image(systemName: selectedCharacterIDs.contains(character.id!) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedCharacterIDs.contains(character.id!) ? .accentColor : .gray)
                                        Text(character.name ?? "Unnamed")
                                        Spacer()
                                        if let hex = character.colorHex, let color = Color(hex: hex) {
                                            Circle().fill(color).frame(width: 8, height: 8)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 50, maxHeight: 150)
                    }
                }
            }
            .padding()
            .navigationTitle("Edit Event: \(event.title ?? "")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") { saveChanges(); dismiss() }
                    .disabled(eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 550, maxWidth: 700,
               minHeight: 500, idealHeight: 650, maxHeight: 800)
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
            
            let trimmedType = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
            event.type = trimmedType.isEmpty ? nil : trimmedType
            
            let trimmedLocation = eventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            event.locationName = trimmedLocation.isEmpty ? nil : trimmedLocation
            
            let trimmedSummary = eventSummaryLine.trimmingCharacters(in: .whitespacesAndNewlines)
            event.summaryLine = trimmedSummary.isEmpty ? nil : trimmedSummary
            
            event.eventDescription = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            event.durationDays = Int16(durationDays)

            let trimmedHex = eventColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            event.eventColorHex = (!trimmedHex.isEmpty && Color(hex: trimmedHex) != nil) ? trimmedHex : nil
            
            event.participatingCharacters = NSSet(array: projectCharacters.filter { selectedCharacterIDs.contains($0.id!) })
            
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                } catch {
                    let nsError = error as NSError
                    // Consider more robust error handling for the user
                    print("Unresolved error saving event changes: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

// Corrected PreviewProvider
struct EditEventView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy context and a sample project and event for the preview
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project for Editing"
        sampleProject.id = UUID() // Ensure ID is set if used by FetchRequest predicate indirectly

        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Event Being Edited"
        sampleEvent.eventDate = Date()
        sampleEvent.project = sampleProject // Associate with project
        sampleEvent.summaryLine = "A preview summary."

        // Add a sample character so the FetchRequest for projectCharacters doesn't fail or result in empty list if UI depends on it
        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Preview Character"
        sampleCharacter.project = sampleProject
        sampleCharacter.id = UUID()
        
        // Ensure the context is saved if your init relies on persisted project for FetchRequest
        // For previews, sometimes it's simpler if the FetchRequest predicate is very basic or
        // if the objects are fully set up.
        // Forcing a save here to ensure the event.project is resolvable.
        do {
            try context.save()
        } catch {
            print("Error saving preview context: \(error)")
        }


        return EditEventView(event: sampleEvent)
            .environment(\.managedObjectContext, context)
    }
}
