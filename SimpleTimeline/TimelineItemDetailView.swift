import SwiftUI
import CoreData

struct TimelineItemDetailView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selectedEvent: EventItem?
    @Binding var selectedArc: CharacterArcItem?
    let provisionalEventDateOverride: Date?

    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var eventColorHexInput: String = ""
    @State private var eventUIColor: Color = .gray
    @State private var editableDurationDays: Int = 0
    @State private var participatingCharacterIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>

    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    init(project: ProjectItem, selectedEvent: Binding<EventItem?>, selectedArc: Binding<CharacterArcItem?>, provisionalEventDateOverride: Date?) {
        self.project = project
        self._selectedEvent = selectedEvent
        self._selectedArc = selectedArc
        self.provisionalEventDateOverride = provisionalEventDateOverride
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.bottom, -2)
    }

    private func syncEventDetailsToState() {
        guard let event = selectedEvent else {
            eventColorHexInput = ""
            eventUIColor = .gray
            participatingCharacterIDs = []
            editableDurationDays = 0
            return
        }
        
        eventColorHexInput = event.eventColorHex ?? ""
        eventUIColor = Color(hex: event.eventColorHex ?? "") ?? .gray
        editableDurationDays = Int(event.durationDays)
        
        if let participants = event.participatingCharacters as? Set<CharacterItem> {
            participatingCharacterIDs = Set(participants.compactMap { $0.id })
        } else {
            participatingCharacterIDs = []
        }
    }
    
    private func updateEventColorFromPicker(_ newColor: Color) {
        if let newHex = newColor.toHex() {
            eventColorHexInput = newHex
            selectedEvent?.eventColorHex = newHex
        }
    }

    private func updateEventColorFromHexInput(_ newHex: String) {
        let trimmedHex = newHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHex.isEmpty {
            selectedEvent?.eventColorHex = nil
            eventUIColor = .gray
        } else if let color = Color(hex: trimmedHex) {
            selectedEvent?.eventColorHex = trimmedHex
            eventUIColor = color
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                viewHeader

                if selectedEvent != nil {
                    eventDetailContent
                } else if let arc = selectedArc {
                    arcDetailContent(arc: arc)
                } else {
                    placeholderContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor).ignoresSafeArea())
        .onAppear(perform: syncEventDetailsToState)
        .onChange(of: selectedEvent) { _, _ in syncEventDetailsToState() }
        // --- Toolbar for Save Event button REMOVED ---
        .alert("Delete Event", isPresented: $showingDeleteConfirmation, presenting: selectedEvent) { eventToDelete in
            Button("Delete", role: .destructive) {
                deleteEvent(event: eventToDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: { eventToDelete in
            Text("Are you sure you want to delete the event '\(eventToDelete.title ?? "this event")'? This action cannot be undone.")
        }
    }

    private var viewHeader: some View {
        HStack {
            Text(selectedEvent != nil ? "Event Details" : (selectedArc != nil ? "Arc Details" : "Details"))
                .font(.title2).fontWeight(.bold)
            Spacer()
            Button {
                selectedEvent = nil
                selectedArc = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private var eventDetailContent: some View {
        if let event = selectedEvent {
            VStack(alignment: .leading, spacing: 12) {
                // Core Info Fields
                Group {
                    fieldLabel("Event Title")
                    TextField("", text: Binding(get: { event.title ?? "" }, set: { event.title = $0 }), prompt: Text("Enter event title"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .fixedSize(horizontal: false, vertical: true)

                    fieldLabel("Type")
                    TextField("", text: Binding(get: { event.type ?? "" }, set: { event.type = $0 }), prompt: Text("e.g., Interview"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .fixedSize(horizontal: false, vertical: true)
                    if !(event.type?.isEmpty ?? true) {
                         Text(event.type ?? "").font(.caption2).foregroundColor(.gray).padding(.leading, 1)
                    }

                    fieldLabel("Color")
                    HStack {
                        ColorPicker("", selection: $eventUIColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: eventUIColor) { _, newColor in updateEventColorFromPicker(newColor) }

                        TextField("", text: $eventColorHexInput, prompt: Text("#RRGGBB"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .fixedSize(horizontal: false, vertical: true)
                            .onChange(of: eventColorHexInput) { _, newHex in updateEventColorFromHexInput(newHex) }
                    }

                    fieldLabel("Start Date")
                    DatePicker("", selection: Binding(
                        get: { provisionalEventDateOverride ?? event.eventDate ?? Date() },
                        set: { event.eventDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()

                    VStack(alignment: .leading, spacing: 3) {
                        fieldLabel("Duration")
                        HStack {
                            Text("\(editableDurationDays) day(s)")
                            Spacer()
                            Stepper("", value: $editableDurationDays, in: 0...365, step: 1)
                                .labelsHidden()
                        }
                    }
                    .onChange(of: editableDurationDays) { _, newValue in
                        event.durationDays = Int16(newValue)
                    }

                    fieldLabel("Location")
                    TextField("", text: Binding(get: { event.locationName ?? "" }, set: { event.locationName = $0 }), prompt: Text("Location name"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().padding(.vertical, 5)

                Group {
                    fieldLabel("Description")
                    TextEditor(text: Binding(
                        get: { event.eventDescription ?? "" },
                        set: { event.eventDescription = $0 }
                    ))
                    .frame(minHeight: 60, idealHeight: 100, maxHeight: 150)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.2)))
                    .font(.system(.body))
                    .fixedSize(horizontal: false, vertical: true)
                }
                Divider().padding(.vertical, 5)
                
                eventParticipantsSection(event: event)
                                
                Divider().padding(.vertical, 10)

                // --- ACTION BUTTONS MOVED AND GROUPED HERE ---
                HStack {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                    // .buttonStyle(.bordered) // Use a less prominent style for delete if preferred
                    
                    Spacer() // Puts space between delete and save

                    Button("Save Event") {
                        saveEventChanges()
                    }
                    .buttonStyle(.borderedProminent) // Make Save more prominent
                    .disabled(selectedEvent == nil || !viewContext.hasChanges)
                    .keyboardShortcut("s", modifiers: .command)
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func eventParticipantsSection(event: EventItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            fieldLabel("Participants (\(participatingCharacterIDs.count))")
            if projectCharacters.isEmpty {
                Text("No characters in this project to add.").foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading) {
                    ForEach(projectCharacters) { character in
                        participantRow(for: character, event: event)
                    }
                }
                // Consider .frame(maxHeight: 150) and wrapping in ScrollView if list can be very long
            }
        }
    }
    
    @ViewBuilder
    private func participantRow(for character: CharacterItem, event: EventItem) -> some View {
        Button(action: {
            toggleCharacterParticipation(character, for: event)
        }) {
            HStack {
                Image(systemName: participatingCharacterIDs.contains(character.id!) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(participatingCharacterIDs.contains(character.id!) ? .accentColor : .gray)
                Text(character.name ?? "Unnamed Character")
                Spacer()
                if let hex = character.colorHex, let color = Color(hex: hex) {
                    Circle().fill(color).frame(width: 10, height: 10)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func toggleCharacterParticipation(_ character: CharacterItem, for event: EventItem) {
        guard let charId = character.id else { return }
        let mutableParticipants = event.mutableSetValue(forKey: "participatingCharacters")
        if participatingCharacterIDs.contains(charId) {
            if mutableParticipants.contains(character) { mutableParticipants.remove(character) }
            participatingCharacterIDs.remove(charId)
        } else {
            if !mutableParticipants.contains(character) { mutableParticipants.add(character) }
            participatingCharacterIDs.insert(charId)
        }
    }
    
    @ViewBuilder
    private func arcDetailContent(arc: CharacterArcItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(arc.name ?? "Untitled Arc").font(.title3).fontWeight(.bold)
            Divider()
            if let charName = arc.character?.name { Text("Character: \(charName)") }
            if let desc = arc.arcDescription, !desc.isEmpty {
                 Text("Description:").fontWeight(.semibold)
                 ScrollView { Text(desc) }.frame(maxHeight: 100)
            }
            if let startEvent = arc.startEvent { Text("Starts at: \(startEvent.title ?? "N/A") (\(startEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            if let peakEvent = arc.peakEvent { Text("Peaks at: \(peakEvent.title ?? "N/A") (\(peakEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            if let endEvent = arc.endEvent { Text("Ends at: \(endEvent.title ?? "N/A") (\(endEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            Spacer()
        }
    }

    private var placeholderContent: some View {
        Text("Select an item on the timeline to see its details, or click '+' in the header to create a new event.")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
    }
    
    private func saveEventChanges() {
        guard let event = selectedEvent else { return }
        updateEventColorFromHexInput(eventColorHexInput)
        
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving event changes: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteEvent(event: EventItem) {
        viewContext.delete(event)
        do {
            try viewContext.save()
            self.selectedEvent = nil
        } catch {
            let nsError = error as NSError
            print("Error deleting event: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct TimelineItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project Details"

        let charForEvent1 = CharacterItem(context: context); charForEvent1.id = UUID(); charForEvent1.name = "Alice"; charForEvent1.project = sampleProject
        let charForEvent2 = CharacterItem(context: context); charForEvent2.id = UUID(); charForEvent2.name = "Bob"; charForEvent2.project = sampleProject

        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Preview Event"; sampleEvent.eventDate = Date(); sampleEvent.durationDays = 0
        sampleEvent.eventDescription = "A detailed description."; sampleEvent.project = sampleProject
        sampleEvent.eventColorHex = "#8E44AD"; sampleEvent.locationName = "Hotel Cosmopolitan"
        sampleEvent.type = "Key Clue Discovery"
        
        sampleEvent.addToParticipatingCharacters(charForEvent1)
        
        return TimelineItemDetailView(
                project: sampleProject,
                selectedEvent: .constant(sampleEvent),
                selectedArc: .constant(nil),
                provisionalEventDateOverride: nil
            )
            .environment(\.managedObjectContext, context)
            .frame(width: 280, height: 800)
    }
}
