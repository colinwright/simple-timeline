import SwiftUI
import CoreData

struct AddEventView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventType: String = ""
    @State private var eventLocation: String = ""
    @State private var eventSummaryLine: String = ""
    @State private var eventDescription: String = ""
    @State private var durationDays: Int = 0
    @State private var eventColorHex: String = ""

    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>
    @State private var selectedCharacterIDs: Set<UUID> = []

    init(project: ProjectItem) {
        self.project = project
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }
    
    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundColor(.gray).padding(.bottom, -3)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Core Event Details").font(.headline)) {
                    VStack(alignment: .leading) { fieldLabel("Title*"); TextField("Event Title", text: $eventTitle) }
                    VStack(alignment: .leading) { fieldLabel("Date*"); DatePicker("", selection: $eventDate, displayedComponents: .date).labelsHidden() }
                    VStack(alignment: .leading) { fieldLabel("Duration"); Stepper("\(durationDays) day(s)", value: $durationDays, in: 0...365) }
                }
                
                Section(header: Text("Categorization & Location").font(.headline)) {
                    VStack(alignment: .leading) { fieldLabel("Type (e.g., Plot Point, Character Beat)"); TextField("Event Type (Optional)", text: $eventType) }
                    VStack(alignment: .leading) { fieldLabel("Color Hex (Optional, e.g., #3498DB)"); TextField("Hex Color Code", text: $eventColorHex) }
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
                                        if let hex = character.colorHex, let color = Color(hex: hex) { Circle().fill(color).frame(width: 8, height: 8) }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }.frame(minHeight: 50, maxHeight: 150)
                    }
                }
            }
            .padding()
            .navigationTitle("Add Event to \(project.title ?? "")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Event") { saveEvent(); dismiss() }
                    .disabled(eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 550, maxWidth: 700, minHeight: 500, idealHeight: 650, maxHeight: 800)
    }

    private func toggleCharacterSelection(_ character: CharacterItem) {
        guard let characterID = character.id else { return }
        if selectedCharacterIDs.contains(characterID) { selectedCharacterIDs.remove(characterID) } else { selectedCharacterIDs.insert(characterID) }
    }

    private func saveEvent() {
        withAnimation {
            let newEvent = EventItem(context: viewContext)
            newEvent.id = UUID()
            newEvent.title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.eventDate = eventDate
            
            let trimmedType = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.type = trimmedType.isEmpty ? nil : trimmedType
            
            let trimmedLocation = eventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.locationName = trimmedLocation.isEmpty ? nil : trimmedLocation
            
            let trimmedSummary = eventSummaryLine.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.summaryLine = trimmedSummary.isEmpty ? nil : trimmedSummary
            
            newEvent.eventDescription = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.durationDays = Int16(durationDays)
            
            let trimmedHex = eventColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            newEvent.eventColorHex = (!trimmedHex.isEmpty && Color(hex: trimmedHex) != nil) ? trimmedHex : nil
            
            newEvent.project = project
            newEvent.participatingCharacters = NSSet(array: projectCharacters.filter { selectedCharacterIDs.contains($0.id!) })
            
            do { try viewContext.save() } catch { print("Error saving new event: \(error.localizedDescription)") }
        }
    }
}

struct AddEventView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project for Adding Event"
        let _ = CharacterItem(context: context, name: "Sample Char", project: sampleProject) // Add char for picker
        
        return AddEventView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}

// Extension for CharacterItem to make preview initialization cleaner
extension CharacterItem {
    convenience init(context: NSManagedObjectContext, name: String, project: ProjectItem) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.project = project
    }
}
