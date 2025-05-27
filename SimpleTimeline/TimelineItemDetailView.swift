import SwiftUI
import CoreData

struct TimelineItemDetailView: View {
    @ObservedObject var project: ProjectItem
    @Binding var selectedEvent: EventItem?
    @Binding var selectedArc: CharacterArcItem?
    let provisionalEventDateOverride: Date? // New property for live date during drag

    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingEditEventSheet = false
    @State private var showingEditArcSheet = false

    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
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

            if let event = selectedEvent {
                Group {
                    Text(event.title ?? "Untitled Event")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Divider()
                    
                    // Use provisional date if available, otherwise the event's actual date
                    Text("Date: \(provisionalEventDateOverride ?? event.eventDate ?? Date(), formatter: itemFormatter)")
                    Text("Duration: \(event.durationDays) day(s)")
                    
                    if let desc = event.eventDescription, !desc.isEmpty {
                        Text("Description:")
                            .fontWeight(.semibold)
                        ScrollView { Text(desc) }
                            .frame(maxHeight: 100)
                            .padding(.bottom, 5)
                    }

                    if let participants = event.participatingCharacters as? Set<CharacterItem>, !participants.isEmpty {
                        Text("Participants:")
                            .fontWeight(.semibold)
                        ForEach(participants.sorted(by: { $0.name ?? "" < $1.name ?? "" }), id: \.self) { char in
                            HStack {
                                if let hex = char.colorHex, let color = Color(hex: hex) {
                                    Circle().fill(color).frame(width: 10, height: 10)
                                }
                                Text(char.name ?? "Unknown Character")
                            }
                        }
                    } else {
                        Text("No participants assigned.").foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 5)

                Spacer()

                Button("Edit Event") {
                    showingEditEventSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .sheet(isPresented: $showingEditEventSheet) {
                    EditEventView(event: event)
                        .environment(\.managedObjectContext, self.viewContext)
                }

            } else if let arc = selectedArc {
                Group {
                    Text(arc.name ?? "Untitled Arc")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Divider()

                    if let charName = arc.character?.name {
                        Text("Character: \(charName)")
                    }
                    
                    if let desc = arc.arcDescription, !desc.isEmpty {
                        Text("Description:").fontWeight(.semibold)
                        ScrollView { Text(desc) }
                            .frame(maxHeight: 100)
                            .padding(.bottom, 5)
                    }

                    if let startEvent = arc.startEvent {
                        Text("Starts at: \(startEvent.title ?? "N/A") (\(startEvent.eventDate ?? Date(), formatter: itemFormatter))")
                    }
                    if let peakEvent = arc.peakEvent {
                        Text("Peaks at: \(peakEvent.title ?? "N/A") (\(peakEvent.eventDate ?? Date(), formatter: itemFormatter))")
                    }
                    if let endEvent = arc.endEvent {
                        Text("Ends at: \(endEvent.title ?? "N/A") (\(endEvent.eventDate ?? Date(), formatter: itemFormatter))")
                    }
                }
                .padding(.bottom, 5)

                Spacer()

                Button("Edit Arc") {
                    showingEditArcSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .sheet(isPresented: $showingEditArcSheet) {
                    if let arcProject = arc.project {
                        EditCharacterArcView(arc: arc, project: arcProject)
                            .environment(\.managedObjectContext, self.viewContext)
                    } else {
                        Text("Error: Arc is not associated with a project.")
                    }
                }
                
            } else {
                Text("Select an item on the timeline to see its details.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TimelineItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project Details"
        sampleProject.id = UUID()

        let sampleEvent = EventItem(context: context)
        sampleEvent.title = "Sample Event for Detail"; sampleEvent.eventDate = Date(); sampleEvent.durationDays = 2
        sampleEvent.eventDescription = "This is a detailed description of the sample event that can be quite long and should wrap and scroll nicely within the allocated space for it."; sampleEvent.project = sampleProject; sampleEvent.id = UUID()
        
        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Detail Character"; sampleCharacter.project = sampleProject; sampleCharacter.id = UUID(); sampleCharacter.colorHex = "#007AFF"
        sampleEvent.addToParticipatingCharacters(sampleCharacter)

        let sampleArc = CharacterArcItem(context: context)
        sampleArc.name = "Sample Arc for Detail"; sampleArc.project = sampleProject; sampleArc.character = sampleCharacter; sampleArc.id = UUID(); sampleArc.startEvent = sampleEvent

        return Group {
            TimelineItemDetailView(
                project: sampleProject,
                selectedEvent: .constant(sampleEvent),
                selectedArc: .constant(nil),
                provisionalEventDateOverride: Calendar.current.date(byAdding: .day, value: 1, to: sampleEvent.eventDate!) // Example override
            )
            .environment(\.managedObjectContext, context)
            .frame(width: 280, height: 400)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Event Detail (Dragged)")

            TimelineItemDetailView(
                project: sampleProject,
                selectedEvent: .constant(nil),
                selectedArc: .constant(sampleArc),
                provisionalEventDateOverride: nil
            )
            .environment(\.managedObjectContext, context)
            .frame(width: 280, height: 400)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Arc Detail")
        }
    }
}
