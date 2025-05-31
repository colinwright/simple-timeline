import SwiftUI
import CoreData

struct TimelineItemDetailView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selectedEvent: EventItem?
    @Binding var selectedArc: CharacterArcItem?
    let provisionalEventDateOverride: Date?

    @Environment(\.managedObjectContext) private var viewContext
    
    // Local state for UI elements, synced with selectedEvent
    @State private var eventTitle: String = ""
    @State private var eventSummaryLine: String = "" // For the new summary line
    @State private var eventType: String = ""
    @State private var eventColorHexInput: String = ""
    @State private var eventUIColor: Color = .gray
    @State private var eventDate: Date = Date()
    @State private var editableDurationDays: Int = 0
    @State private var eventLocationName: String = ""
    @State private var eventDescription: String = ""
    
    @State private var participatingCharacterIDs: Set<UUID> = [] // Tracks IDs for UI state
    @State private var showingDeleteConfirmation = false

    @FetchRequest private var projectCharacters: FetchedResults<CharacterItem>

    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateStyle = .medium; return formatter
    }
    
    init(project: ProjectItem, selectedEvent: Binding<EventItem?>, selectedArc: Binding<CharacterArcItem?>, provisionalEventDateOverride: Date?) {
        self.project = project
        self._selectedEvent = selectedEvent
        self._selectedArc = selectedArc
        self.provisionalEventDateOverride = provisionalEventDateOverride
        
        let currentProjectForFetch = selectedEvent.wrappedValue?.project ?? project
        _projectCharacters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", currentProjectForFetch),
            animation: .default
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.gray).padding(.bottom, -2)
    }

    private func syncEventDetailsToState() {
        guard let event = selectedEvent else {
            eventTitle = ""; eventSummaryLine = ""; eventType = ""; eventColorHexInput = ""; eventUIColor = .gray
            eventDate = Date(); editableDurationDays = 0; eventLocationName = ""
            eventDescription = ""; participatingCharacterIDs = []
            return
        }
        
        eventTitle = event.title ?? ""
        eventSummaryLine = event.summaryLine ?? ""
        eventType = event.type ?? ""
        eventColorHexInput = event.eventColorHex ?? ""
        eventUIColor = Color(hex: event.eventColorHex ?? "") ?? .gray
        eventDate = provisionalEventDateOverride ?? event.eventDate ?? Date()
        editableDurationDays = Int(event.durationDays)
        eventLocationName = event.locationName ?? ""
        eventDescription = event.eventDescription ?? ""

        participatingCharacterIDs = Set((event.participatingCharacters as? Set<CharacterItem>)?.compactMap { $0.id } ?? [])
    }
    
    private func syncStateToEventDetailsOnSave() { // Renamed to clarify when it's used
        guard let event = selectedEvent else { return }

        event.title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let trimmedType = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
        event.type = trimmedType.isEmpty ? nil : trimmedType
        
        let trimmedHex = eventColorHexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHex.isEmpty {
            event.eventColorHex = nil
        } else if Color(hex: trimmedHex) != nil {
            event.eventColorHex = trimmedHex
        }
        
        if provisionalEventDateOverride == nil { event.eventDate = eventDate }
        // event.durationDays is updated live by its .onChange
        
        let trimmedLocation = eventLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        event.locationName = trimmedLocation.isEmpty ? nil : trimmedLocation
        
        event.eventDescription = eventDescription
        
        let trimmedSummary = eventSummaryLine.trimmingCharacters(in: .whitespacesAndNewlines)
        event.summaryLine = trimmedSummary.isEmpty ? nil : trimmedSummary

        // Participants are now updated live in toggleCharacterParticipation.
        // This part ensures consistency if needed, but might be redundant if live updates are robust.
        let mutableParticipants = event.mutableSetValue(forKey: "participatingCharacters")
        let currentParticipantObjects = projectCharacters.filter { participatingCharacterIDs.contains($0.id!) }
        
        // Create sets for comparison to avoid unnecessary modifications if they are already in sync
        let existingParticipantsInEvent = (mutableParticipants as? Set<CharacterItem>) ?? Set<CharacterItem>()
        let newParticipantSet = Set(currentParticipantObjects)

        if existingParticipantsInEvent != newParticipantSet {
            mutableParticipants.removeAllObjects()
            newParticipantSet.forEach { mutableParticipants.add($0) }
        }
    }

    private func updateEventUIColorFromPicker(_ newUIColor: Color) {
        if let newHex = newUIColor.toHex() { eventColorHexInput = newHex }
    }

    private func updateEventColorHexFromInput(_ newHexInput: String) {
        eventColorHexInput = newHexInput
        let trimmed = newHexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        eventUIColor = Color(hex: trimmed) ?? (trimmed.isEmpty ? .gray : eventUIColor)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                viewHeader
                if selectedEvent != nil { eventDetailContent }
                else if let arc = selectedArc { arcDetailContent(arc: arc) }
                else { placeholderContent }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(NSColor.controlBackgroundColor).ignoresSafeArea())
        .onAppear(perform: syncEventDetailsToState)
        .onChange(of: selectedEvent) { oldValue, newValue in syncEventDetailsToState() }
        .onChange(of: provisionalEventDateOverride) { oldValue, newValue in
            if let newDate = newValue, selectedEvent != nil { eventDate = newDate }
            else if selectedEvent != nil { eventDate = selectedEvent?.eventDate ?? Date() }
        }
        .alert("Delete Event", isPresented: $showingDeleteConfirmation, presenting: selectedEvent) { eventToDelete in
            Button("Delete", role: .destructive) { deleteEvent(event: eventToDelete) }
            Button("Cancel", role: .cancel) {}
        } message: { eventToDelete in Text("Are you sure you want to delete '\(eventToDelete.title ?? "this event")'?") }
    }

    private var viewHeader: some View {
        HStack {
            Text(selectedEvent != nil ? "Event Details" : (selectedArc != nil ? "Arc Details" : "Details"))
                .font(.title2).fontWeight(.bold)
            Spacer()
            Button { selectedEvent = nil; selectedArc = nil }
            label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private var eventDetailContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group { // Group 1: Title and Summary
                fieldLabel("Event Title")
                TextField("", text: $eventTitle, prompt: Text("Enter event title"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)

                fieldLabel("Summary") // << RENAMED and MOVED
                TextField("", text: $eventSummaryLine, prompt: Text("One-line summary (Optional)"), axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...2)
                    .frame(minHeight: 30)
                    .padding(.bottom, 12)
            }

            Divider().padding(.vertical, 8)

            Group { // Group 2: Type, Color, Date, Duration, Location
                fieldLabel("Type")
                TextField("", text: $eventType, prompt: Text("e.g., Inciting Incident"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)

                fieldLabel("Color")
                HStack {
                    ColorPicker("", selection: $eventUIColor, supportsOpacity: false).labelsHidden()
                        .onChange(of: eventUIColor) { oldValue, newValue in updateEventUIColorFromPicker(newValue) }
                    TextField("", text: $eventColorHexInput, prompt: Text("#RRGGBB")).textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: eventColorHexInput) { oldValue, newValue in updateEventColorHexFromInput(newValue) }
                }.padding(.bottom, 10)

                fieldLabel("Start Date")
                DatePicker("", selection: $eventDate, displayedComponents: .date).labelsHidden().disabled(provisionalEventDateOverride != nil)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 3) {
                    fieldLabel("Duration")
                    HStack {
                        Text("\(editableDurationDays) day(s)")
                        Spacer()
                        Stepper("", value: $editableDurationDays, in: 0...365)
                            .labelsHidden()
                            .onChange(of: editableDurationDays) { oldValue, newValue in
                                if let event = selectedEvent { event.durationDays = Int16(newValue) }
                            }
                    }
                }.padding(.bottom, 10)

                fieldLabel("Location")
                TextField("", text: $eventLocationName, prompt: Text("Location name (Optional)")).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.bottom, 12)
            
            Divider().padding(.vertical, 8)

            Group { // Group 3: Description
                fieldLabel("Description")
                TextEditor(text: $eventDescription)
                    .frame(minHeight: 80, idealHeight: 100, maxHeight: 120) // Adjusted height
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .font(.system(.body))
            }
            .padding(.bottom, 12)
            
            Divider().padding(.vertical, 8)

            // Participants Section
            if !projectCharacters.isEmpty {
                fieldLabel("Participants (\(participatingCharacterIDs.count))")
                    .padding(.bottom, 4)
                VStack(alignment: .leading) {
                    ForEach(projectCharacters) { character in
                        participantRow(for: character)
                            .padding(.vertical, 3)
                    }
                }
                .padding(.bottom, 12)
            } else {
                Text("No characters in this project to add as participants.")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
            }
            
            // Action Buttons
            HStack {
                Button(role: .destructive) { showingDeleteConfirmation = true }
                label: { Label("Delete Event", systemImage: "trash") }
                
                Spacer()
                Button("Save Changes") { saveEventChanges() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedEvent == nil || eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.vertical, 15)
        }
    }
    
    @ViewBuilder
    private func participantRow(for character: CharacterItem) -> some View {
        Button(action: { toggleCharacterParticipation(character) }) {
            HStack {
                Image(systemName: participatingCharacterIDs.contains(character.id!) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(participatingCharacterIDs.contains(character.id!) ? .accentColor : .gray)
                Text(character.name ?? "Unnamed Character")
                Spacer()
                if let hex = character.colorHex, let color = Color(hex: hex) {
                    Circle().fill(color).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // << MODIFIED for Live Update >>
    private func toggleCharacterParticipation(_ character: CharacterItem) {
        guard let charId = character.id, let event = selectedEvent else { return }

        let mutableParticipants = event.mutableSetValue(forKey: "participatingCharacters")

        if participatingCharacterIDs.contains(charId) {
            // Remove
            participatingCharacterIDs.remove(charId)
            // Directly modify the NSManagedObject's relationship set
            if mutableParticipants.contains(character) {
                mutableParticipants.remove(character)
            }
        } else {
            // Add
            participatingCharacterIDs.insert(charId)
            // Directly modify the NSManagedObject's relationship set
            if !mutableParticipants.contains(character) {
                mutableParticipants.add(character)
            }
        }
        // This direct modification should make the context "dirty" and
        // @ObservedObject event in EventBlockView should pick up the change.
    }
    
    @ViewBuilder
    private func arcDetailContent(arc: CharacterArcItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(arc.name ?? "Untitled Arc").font(.title3).fontWeight(.bold); Divider()
            if let charName = arc.character?.name { Text("Character: \(charName)") }
            if let desc = arc.arcDescription, !desc.isEmpty { Text("Description:").fontWeight(.semibold); ScrollView { Text(desc) }.frame(maxHeight: 100) }
            if let startEvent = arc.startEvent { Text("Starts at: \(startEvent.title ?? "N/A") (\(startEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            if let peakEvent = arc.peakEvent { Text("Peaks at: \(peakEvent.title ?? "N/A") (\(peakEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            if let endEvent = arc.endEvent { Text("Ends at: \(endEvent.title ?? "N/A") (\(endEvent.eventDate ?? Date(), formatter: itemFormatter))") }
            Spacer()
        }
    }

    private var placeholderContent: some View {
        Text("Select an event on the timeline to see its details, or click '+' in the header to create a new event.")
            .foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).padding()
    }
    
    private func saveEventChanges() {
        guard selectedEvent != nil else { return }
        syncStateToEventDetailsOnSave() // Use the renamed sync function
        if viewContext.hasChanges {
            do { try viewContext.save() }
            catch { let nsError = error as NSError; print("Error saving event changes: \(nsError), \(nsError.userInfo)") }
        }
    }

    private func deleteEvent(event: EventItem) {
        viewContext.delete(event)
        do { try viewContext.save(); self.selectedEvent = nil }
        catch { let nsError = error as NSError; print("Error deleting event: \(nsError), \(nsError.userInfo)") }
    }
}

struct TimelineItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context); sampleProject.title = "Preview Project Details"
        let char1 = CharacterItem(context: context); char1.id = UUID(); char1.name = "Alice"; char1.project = sampleProject; char1.colorHex = "#FF0000"
        let char2 = CharacterItem(context: context); char2.id = UUID(); char2.name = "Bob"; char2.project = sampleProject; char2.colorHex = "#00FF00"
        let char3 = CharacterItem(context: context); char3.id = UUID(); char3.name = "Charlie"; char3.project = sampleProject; char3.colorHex = "#0000FF"

        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Detailed Preview Event"; sampleEvent.eventDate = Date(); sampleEvent.durationDays = 1
        sampleEvent.eventDescription = "A very detailed description of what happens during this pivotal event in the story, potentially quite long.";
        sampleEvent.summaryLine = "Key decision made by Alice."
        sampleEvent.project = sampleProject; sampleEvent.eventColorHex = "#2ECC71"; sampleEvent.locationName = "The Old Library"
        sampleEvent.type = "Decision Point"
        sampleEvent.addToParticipatingCharacters(char1)
        sampleEvent.addToParticipatingCharacters(char2)
        // sampleEvent.addToParticipatingCharacters(char3) // Keep participants to 2 for initial preview
        
        do { try context.save() } catch { print("Preview save error: \(error)") }

        return StatefulPreviewWrapper_TIDV(selectedEvent: sampleEvent, project: sampleProject)
    }
    
    struct StatefulPreviewWrapper_TIDV: View {
        @State var selectedEvent: EventItem?
        var project: ProjectItem

        init(selectedEvent: EventItem?, project: ProjectItem) {
            self._selectedEvent = State(initialValue: selectedEvent)
            self.project = project
        }

        var body: some View {
            TimelineItemDetailView(
                project: project,
                selectedEvent: $selectedEvent,
                selectedArc: .constant(nil),
                provisionalEventDateOverride: nil
            )
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .frame(width: 320, height: 950)
        }
    }
}
