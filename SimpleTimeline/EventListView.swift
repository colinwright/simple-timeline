import SwiftUI
import CoreData

struct EventListView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var events: FetchedResults<EventItem>

    @State private var showingAddEventView = false
    @State private var eventToEdit: EventItem?
    
    // State to track expanded events by their ID (for description)
    @State private var expandedEventIDs: Set<UUID> = []

    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
        _events = FetchRequest<EventItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \EventItem.eventDate, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Events for: \(project.title ?? "Untitled Project")")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddEventView = true
                } label: {
                    Label("Add Event", systemImage: "plus.circle.fill")
                }
            }
            .padding(.bottom)

            if events.isEmpty {
                Text("No events yet. Click the '+' button to add one.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(events) { event in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) { // Added spacing
                                Text(event.title ?? "Untitled Event")
                                    .font(.body)
                                Text("Date: \(event.eventDate ?? Date(), formatter: itemFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if let description = event.eventDescription, !description.isEmpty {
                                    Text(description)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(expandedEventIDs.contains(event.id!) ? nil : 2)
                                }
                                
                                // Display Participating Characters
                                if let characters = event.participatingCharacters as? Set<CharacterItem>, !characters.isEmpty {
                                    HStack(alignment: .top, spacing: 4) { // Changed to .top alignment
                                        Text("Participants:")
                                            .font(.caption2) // Smaller font for the label
                                            .foregroundColor(.gray)
                                        // Wrap character names if they get too long
                                        VStack(alignment: .leading, spacing: 2) { // VStack for potentially multiple lines of characters
                                            ForEach(characters.sorted(by: { $0.name ?? "" < $1.name ?? "" }), id: \.self) { character in
                                                HStack(spacing: 3) {
                                                    // --- Debugging Print Statement ---
                                                    let _ = print("Character: \(character.name ?? "N/A"), Hex: \(character.colorHex ?? "NIL"), Converted Color: \(String(describing: Color(hex: character.colorHex ?? "")))")
                                                    // --- End Debugging ---
                                                    
                                                    let charColor = (character.colorHex != nil ? Color(hex: character.colorHex!) : Color.gray) ?? .gray
                                                    Circle().fill(charColor).frame(width: 7, height: 7)
                                                    Text(character.name ?? "Unknown")
                                                        .font(.caption2) // Smaller font for character names
                                                        .foregroundColor(charColor) // Apply character's color to the name
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 2) // Little space above participants list
                                }
                            }
                            Spacer()
                            
                            HStack(spacing: 8) {
                                if let description = event.eventDescription, !description.isEmpty {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            toggleExpansion(for: event)
                                        }
                                    } label: {
                                        Image(systemName: expandedEventIDs.contains(event.id!) ? "chevron.up" : "chevron.down")
                                            .imageScale(.small)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Menu {
                                    Button {
                                        eventToEdit = event
                                    } label: {
                                        Label("Edit Event", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deleteEvent(event)
                                    } label: {
                                        Label("Delete Event", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .imageScale(.medium)
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 28, height: 28, alignment: .center)
                                .contentShape(Rectangle())
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                eventToEdit = event
                            } label: {
                                Label("Edit Event", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Label("Delete Event", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteEventsFromOffsets)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddEventView) {
            AddEventView(project: project)
        }
        .sheet(item: $eventToEdit) { eventToPresent in
            EditEventView(event: eventToPresent)
        }
    }
    
    private func toggleExpansion(for event: EventItem) {
        guard let eventID = event.id else { return }
        if expandedEventIDs.contains(eventID) {
            expandedEventIDs.remove(eventID)
        } else {
            expandedEventIDs.insert(eventID)
        }
    }

    private func deleteEventsFromOffsets(offsets: IndexSet) {
        withAnimation {
            offsets.map { events[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }
    
    private func deleteEvent(_ event: EventItem) {
        withAnimation {
            viewContext.delete(event)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error saving context: \(nsError), \(nsError.userInfo)")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct EventListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Preview Project"
        sampleProject.creationDate = Date()
        sampleProject.id = UUID()
        
        let char1 = CharacterItem(context: context)
        char1.id = UUID()
        char1.name = "Alice"
        char1.colorHex = "#FF0000" // Red
        char1.project = sampleProject
        
        let char2 = CharacterItem(context: context)
        char2.id = UUID()
        char2.name = "Bob"
        char2.colorHex = "#00FF00" // Green
        char2.project = sampleProject
        
        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Tea Party"
        sampleEvent.eventDate = Date()
        sampleEvent.eventDescription = "A lovely tea party in the garden."
        sampleEvent.id = UUID()
        sampleEvent.project = sampleProject
        sampleEvent.participatingCharacters = NSSet(array: [char1, char2])


        let sampleEvent2 = EventItem(context: context)
        sampleEvent2.title = "Adventure Begins"
        sampleEvent2.eventDate = Date().addingTimeInterval(3600) // One hour later
        sampleEvent2.eventDescription = "The heroes set off on a grand adventure. This description is a bit longer to test how it wraps or expands."
        sampleEvent2.id = UUID()
        sampleEvent2.project = sampleProject
        sampleEvent2.participatingCharacters = NSSet(array: [char1])
        
        return EventListView(project: sampleProject)
            .environment(\.managedObjectContext, context)
            .frame(width: 400, height: 600) // Increased height for preview
    }
}
