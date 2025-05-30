import SwiftUI
import CoreData

struct TimelineView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selection: MainViewSelection

    // Fetched Results
    @FetchRequest private var events: FetchedResults<EventItem>
    @FetchRequest private var characters: FetchedResults<CharacterItem>
    @FetchRequest private var characterArcs: FetchedResults<CharacterArcItem>

    // Timeline drawing constants
    private let eventBlockBaseHeight: CGFloat = 50
    private let arcHeight: CGFloat = 10
    private let peakIndicatorHeight: CGFloat = 14
    private let horizontalPadding: CGFloat = 20
    private let characterLaneHeaderWidth: CGFloat = 150
    private let laneHeight: CGFloat = 40
    private let instantaneousEventWidth: CGFloat = 10
    private let topOffsetForTimeAxis: CGFloat = 50
    private let detailPanelWidth: CGFloat = 280

    // State for zoom level
    @State private var currentPixelsPerDay: CGFloat = 60
    private let absoluteMinPixelsPerDay: CGFloat = 10
    private let maxPixelsPerDay: CGFloat = 300
    private let zoomFactor: CGFloat = 1.4

    // For Magnification Gesture
    @GestureState private var magnifyBy: CGFloat = 1.0

    // State for selected items to show in the detail panel
    @State private var selectedEventForDetail: EventItem?
    @State private var selectedArcForDetail: CharacterArcItem?
    
    @State private var activelyDraggingEventID: UUID?
    @State private var originalDateForDraggedEvent: Date?

    init(project: ProjectItem, selection: Binding<MainViewSelection>) {
        _project = ObservedObject(initialValue: project)
        _selection = selection
        
        let projectPredicate = NSPredicate(format: "project == %@", project)
        
        _events = FetchRequest<EventItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \EventItem.eventDate, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        _characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        _characterArcs = FetchRequest<CharacterArcItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterArcItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            timelinePanel
            if selectedEventForDetail != nil || selectedArcForDetail != nil {
                TimelineItemDetailView(
                    project: project,
                    selectedEvent: $selectedEventForDetail,
                    selectedArc: $selectedArcForDetail,
                    provisionalEventDateOverride: (selectedEventForDetail?.id == activelyDraggingEventID ? selectedEventForDetail?.eventDate : nil)
                )
                .frame(width: detailPanelWidth)
                .layoutPriority(1)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: selectedEventForDetail != nil || selectedArcForDetail != nil)
            }
        }
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Timeline",
                    isProjectTitleClickable: true,
                    projectHomeAction: { selection = .projectHome }
                )
            } trailing: {
                // --- MODIFIED HEADER BUTTONS ---
                HStack {
                    Button {
                        addNewEvent() // Action to add a new event
                    } label: {
                        Label("Add Event", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly) // Icon only
                    }
                    .help("Add New Event") // Tooltip

                    Button {
                        withAnimation(.easeInOut) {
                            currentPixelsPerDay = min(maxPixelsPerDay, currentPixelsPerDay * zoomFactor)
                        }
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                            .labelStyle(.iconOnly) // Icon only
                    }
                    .keyboardShortcut("+", modifiers: .command)
                    .help("Zoom In")


                    Button {
                         withAnimation(.easeInOut) {
                            currentPixelsPerDay = max(absoluteMinPixelsPerDay, currentPixelsPerDay / zoomFactor)
                        }
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                            .labelStyle(.iconOnly) // Icon only
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Zoom Out")
                }
            }
            
            if characters.isEmpty && events.isEmpty && characterArcs.isEmpty {
                 Text("No data to display on the timeline. Click '+' in the header to add an event.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else if let currentRange = dateRange {
                GeometryReader { geometry in
                    timelineScrollableContent(
                        currentRange: currentRange,
                        geometry: geometry,
                        charIndices: buildCharacterIndicesMap()
                    )
                }
            } else {
                 Text("Add events to see the timeline, or manage characters.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            deselectAllItems()
        }
    }
    
    // MARK: - Add New Event
    private func addNewEvent() {
        withAnimation {
            // Create a new EventItem instance
            let newEvent = EventItem(context: viewContext)
            newEvent.id = UUID()
            newEvent.title = "New Event" // Default title
            
            // Set a default date (e.g., today or middle of current timeline view)
            if let currentTimelineRange = dateRange {
                let calendar = Calendar.current
                if let middleDate = calendar.date(byAdding: .day, value: (calendar.dateComponents([.day], from: currentTimelineRange.start, to: currentTimelineRange.end).day ?? 0) / 2, to: currentTimelineRange.start) {
                    newEvent.eventDate = middleDate
                } else {
                    newEvent.eventDate = currentTimelineRange.start
                }
            } else {
                newEvent.eventDate = Date() // Fallback to today
            }
            
            newEvent.durationDays = 0 // Default duration
            newEvent.project = self.project // Associate with the current project
            // Initialize other optional fields as nil or with defaults if desired
            newEvent.type = ""
            newEvent.locationName = ""
            newEvent.eventDescription = ""
            newEvent.eventColorHex = nil

            // Deselect any currently selected arc
            self.selectedArcForDetail = nil
            // Set the new event as the one to be detailed (and thus edited)
            self.selectedEventForDetail = newEvent
        }
    }
        
    // ... (Rest of TimelineView.swift: dateRange, buildCharacterIndicesMap, other helpers,
    //      EventBlockView, CharacterArcView, TimeAxisView, and Previews remain the same
    //      as the complete version from Fri, May 30 2025 11:51 AM CDT, which fixed the
    //      EventBlockView display) ...
    // MARK: - Computed Properties for Layout
    private var dateRange: (start: Date, end: Date)? {
        var allDates: [Date] = []
        let calendar = Calendar.current

        for event in events {
            if let date = event.eventDate {
                allDates.append(date)
                allDates.append(calendar.date(byAdding: .day, value: Int(event.durationDays), to: date) ?? date)
            }
        }
        for arc in characterArcs {
            if let startDate = arc.startEvent?.eventDate { allDates.append(startDate) }
            if let peakDate = arc.peakEvent?.eventDate { allDates.append(peakDate) }
            if let endDate = arc.endEvent?.eventDate {
                allDates.append(endDate)
                allDates.append(calendar.date(byAdding: .day, value: Int(arc.endEvent?.durationDays ?? 0), to: endDate) ?? endDate)
            }
        }

        guard !allDates.isEmpty else {
            if !characters.isEmpty {
                let today = Date()
                return (calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                        calendar.date(byAdding: .day, value: 29, to: today) ?? today)
            }
            return nil
        }

        let minDate = allDates.min() ?? Date()
        let maxDate = allDates.max() ?? Date()
        
        let paddedStartDate = calendar.date(byAdding: .day, value: -1, to: minDate) ?? minDate
        var paddedEndDate = calendar.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate

        if Calendar.current.isDate(paddedEndDate, inSameDayAs: paddedStartDate) {
             paddedEndDate = calendar.date(byAdding: .day, value: 10, to: paddedEndDate) ?? paddedEndDate
        }
        if paddedStartDate >= paddedEndDate {
            paddedEndDate = calendar.date(byAdding: .day, value: 10, to: paddedStartDate) ?? paddedStartDate
        }
        
        return (paddedStartDate, paddedEndDate)
    }
    
    private func buildCharacterIndicesMap() -> [UUID: Int] {
        var indices: [UUID: Int] = [:]
        for (index, character) in characters.enumerated() {
            if let charID = character.id {
                indices[charID] = index
            }
        }
        return indices
    }
    
    private func calculateTotalTimelineContentWidth(for range: (start: Date, end: Date), pixelsPerDayToUse: CGFloat) -> CGFloat {
        let durationInDays = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1
        return CGFloat(max(durationInDays, 1)) * pixelsPerDayToUse
    }
    
    private func deselectAllItems() {
        if selectedEventForDetail != nil || selectedArcForDetail != nil || activelyDraggingEventID != nil {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.selectedEventForDetail = nil
                self.selectedArcForDetail = nil
                self.activelyDraggingEventID = nil
                self.originalDateForDraggedEvent = nil
            }
        }
    }
    
    private func handleEventDragStateChange(event: EventItem, isDragging: Bool, originalDragStartDate: Date?, newProvisionalDate: Date?) {
        if isDragging {
            self.activelyDraggingEventID = event.id
            if self.originalDateForDraggedEvent == nil {
                self.originalDateForDraggedEvent = originalDragStartDate
            }
            if self.selectedEventForDetail?.id == event.id {
                self.selectedEventForDetail = event
            }
        } else {
            self.activelyDraggingEventID = nil
            self.originalDateForDraggedEvent = nil
            if self.selectedEventForDetail?.id == event.id {
                 self.selectedEventForDetail = event
            }
        }
    }
    // MARK: - Scrollable Content and Layers
    @ViewBuilder
    private func timelineScrollableContent(
        currentRange: (start: Date, end: Date),
        geometry: GeometryProxy,
        charIndices: [UUID: Int]
    ) -> some View {
        let availableWidthForContent = geometry.size.width - characterLaneHeaderWidth - (horizontalPadding * 2)
        let durationInDaysForRange = CGFloat(max(1, Calendar.current.dateComponents([.day], from: currentRange.start, to: currentRange.end).day ?? 1))
        
        let minPixelsPerDayToFill = (availableWidthForContent > 0 && durationInDaysForRange > 0) ? (availableWidthForContent / durationInDaysForRange) : absoluteMinPixelsPerDay
        let effectivePixelsPerDay = max(currentPixelsPerDay, minPixelsPerDayToFill, absoluteMinPixelsPerDay)
        let actualTimelineContentWidth = calculateTotalTimelineContentWidth(for: currentRange, pixelsPerDayToUse: effectivePixelsPerDay)
        
        let totalWidthForZStack = max(geometry.size.width, actualTimelineContentWidth + characterLaneHeaderWidth + (horizontalPadding * 2))


        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                tappableBackgroundLayer(totalWidth: totalWidthForZStack, totalHeight: calculateTotalHeight())
                characterLaneVisualsLayer(totalWidth: totalWidthForZStack)
                eventLayer(currentRange: currentRange, effectivePixelsPerDay: effectivePixelsPerDay, charIndices: charIndices)
                characterArcLayer(currentRange: currentRange, effectivePixelsPerDay: effectivePixelsPerDay, charIndices: charIndices)
                timeAxisLayer(currentRange: currentRange, actualTimelineContentWidth: actualTimelineContentWidth, effectivePixelsPerDay: effectivePixelsPerDay)
            }
            .frame(minWidth: geometry.size.width, idealWidth: totalWidthForZStack, maxWidth: totalWidthForZStack,
                   minHeight: calculateTotalHeight(), idealHeight: calculateTotalHeight(), maxHeight: calculateTotalHeight())

            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { currentState, gestureState, transaction in
                        gestureState = currentState
                    }
                    .onEnded { value in
                        let newPixelsPerDay = currentPixelsPerDay * value
                        withAnimation(.easeInOut) {
                            currentPixelsPerDay = max(absoluteMinPixelsPerDay, min(maxPixelsPerDay, newPixelsPerDay))
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func tappableBackgroundLayer(totalWidth: CGFloat, totalHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: totalWidth, height: totalHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                deselectAllItems()
            }
            .zIndex(-1)
    }

    @ViewBuilder
    private func characterLaneVisualsLayer(totalWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                HStack {
                    Text(character.name ?? "Unnamed Character")
                        .font(.caption).padding(5)
                        .frame(width: characterLaneHeaderWidth - 10, height: laneHeight, alignment: .leading)
                        .background(index.isMultiple(of: 2) ? Color.gray.opacity(0.1) : Color.clear)
                    Spacer()
                }
                .frame(width: totalWidth, height: laneHeight)
                if index < characters.count - 1 {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1).offset(x: characterLaneHeaderWidth)
                }
            }
            if !events.isEmpty || !characterArcs.isEmpty || characters.isEmpty {
                HStack {
                     Text(characters.isEmpty && events.filter { $0.participatingCharacters?.count == 0 }.isEmpty ? "Timeline" : "General Events")
                        .font(.caption).padding(5)
                        .frame(width: characterLaneHeaderWidth - 10, height: laneHeight, alignment: .leading)
                        .background((characters.count).isMultiple(of: 2) ? Color.gray.opacity(0.1) : Color.clear)
                    Spacer()
                }
                .frame(width: totalWidth, height: laneHeight)
            }
        }
        .padding(.top, topOffsetForTimeAxis)
        .zIndex(0)
    }

    @ViewBuilder
    private func eventLayer(currentRange: (start: Date, end: Date), effectivePixelsPerDay: CGFloat, charIndices: [UUID: Int]) -> some View {
        ForEach(events) { event in
            if let eventDate = event.eventDate {
                let participatingChars = (event.participatingCharacters as? Set<CharacterItem>) ?? Set()
                let currentEventXPos = xPosition(for: eventDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                
                if participatingChars.isEmpty {
                    EventBlockView(
                        event: event, displayCharacter: nil, pixelsPerDay: effectivePixelsPerDay,
                        instantaneousEventWidth: instantaneousEventWidth,
                        currentXPosition: currentEventXPos,
                        timelineStartDate: currentRange.start,
                        yPosition: findYPositionForEvent(event, onCharacter: nil, charIndices: charIndices, eventHeight: eventBlockBaseHeight),
                        height: eventBlockBaseHeight,
                        isSelected: self.selectedEventForDetail?.id == event.id,
                        isBeingActivelyDragged: self.activelyDraggingEventID == event.id,
                        onTap: {
                            self.selectedArcForDetail = nil
                            self.selectedEventForDetail = (self.selectedEventForDetail?.id == event.id ? nil : event)
                            self.activelyDraggingEventID = nil; self.originalDateForDraggedEvent = nil
                        },
                        onDragStateChanged: { dragging, originalDate, newDate in
                            handleEventDragStateChange(event: event, isDragging: dragging, originalDragStartDate: originalDate, newProvisionalDate: newDate)
                        }
                    )
                    .environment(\.managedObjectContext, self.viewContext)
                    .zIndex(self.selectedEventForDetail?.id == event.id || self.activelyDraggingEventID == event.id ? 2.5 : 2)
                } else {
                    ForEach(Array(participatingChars.sorted(by: { $0.name ?? "" < $1.name ?? "" })), id: \.self) { character in
                        EventBlockView(
                            event: event, displayCharacter: character, pixelsPerDay: effectivePixelsPerDay,
                            instantaneousEventWidth: instantaneousEventWidth,
                            currentXPosition: currentEventXPos,
                            timelineStartDate: currentRange.start,
                            yPosition: findYPositionForEvent(event, onCharacter: character, charIndices: charIndices, eventHeight: eventBlockBaseHeight),
                            height: eventBlockBaseHeight,
                            isSelected: self.selectedEventForDetail?.id == event.id,
                            isBeingActivelyDragged: self.activelyDraggingEventID == event.id,
                            onTap: {
                                self.selectedArcForDetail = nil
                                self.selectedEventForDetail = (self.selectedEventForDetail?.id == event.id ? nil : event)
                                self.activelyDraggingEventID = nil; self.originalDateForDraggedEvent = nil
                            },
                            onDragStateChanged: { dragging, originalDate, newDate in
                                handleEventDragStateChange(event: event, isDragging: dragging, originalDragStartDate: originalDate, newProvisionalDate: newDate)
                            }
                        )
                        .environment(\.managedObjectContext, self.viewContext)
                        .zIndex(self.selectedEventForDetail?.id == event.id && event.participatingCharacters?.contains(character) == true || self.activelyDraggingEventID == event.id ? 2.5 : 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func characterArcLayer(currentRange: (start: Date, end: Date), effectivePixelsPerDay: CGFloat, charIndices: [UUID: Int]) -> some View {
        ForEach(characterArcs) { arc in
            if let char = arc.character, let charID = char.id, let charIndex = charIndices[charID],
               let startEvent = arc.startEvent, let startDate = startEvent.eventDate,
               let endEventUnwrapped = arc.endEvent, let endDate = endEventUnwrapped.eventDate {
                
                let arcStartX = xPosition(for: startDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                let endEventActualEndDate = Calendar.current.date(byAdding: .day, value: Int(endEventUnwrapped.durationDays), to: endDate) ?? endDate
                let arcEndX = xPosition(for: endEventActualEndDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                
                let peakX: CGFloat? = {
                    if let peakEvent = arc.peakEvent, let peakDate = peakEvent.eventDate {
                        return xPosition(for: peakDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                    }
                    return nil
                }()
                
                let arcYPosition = topOffsetForTimeAxis + (CGFloat(charIndex) * laneHeight) + (laneHeight * 0.65)
                
                CharacterArcView(
                    arc: arc,
                    startX: arcStartX,
                    endX: arcEndX,
                    peakX: peakX,
                    yPosition: arcYPosition,
                    height: arcHeight,
                    peakIndicatorHeight: peakIndicatorHeight,
                    color: Color(hex: char.colorHex ?? "") ?? .purple.opacity(0.7),
                    isSelected: self.selectedArcForDetail?.id == arc.id,
                    onTap: {
                        self.selectedEventForDetail = nil
                        self.selectedArcForDetail = (self.selectedArcForDetail?.id == arc.id ? nil : arc)
                    }
                ).zIndex(1)
            }
        }
    }

    @ViewBuilder
    private func timeAxisLayer(currentRange: (start: Date, end: Date), actualTimelineContentWidth: CGFloat, effectivePixelsPerDay: CGFloat) -> some View {
        TimeAxisView(
            startDate: currentRange.start,
            endDate: currentRange.end,
            totalWidth: actualTimelineContentWidth,
            offsetX: 0,
            pixelsPerDay: effectivePixelsPerDay
        )
        .frame(height: 40)
        .padding(.horizontal, horizontalPadding)
        .offset(x: characterLaneHeaderWidth, y: 10)
        .zIndex(3)
    }
    
    private func xPosition(for date: Date, timelineStartDate: Date, currentPixelsPerDay: CGFloat) -> CGFloat {
        let daysFromStart = Calendar.current.dateComponents([.day], from: timelineStartDate, to: date).day ?? 0
        return characterLaneHeaderWidth + CGFloat(daysFromStart) * currentPixelsPerDay + horizontalPadding
    }

    private func calculateTotalHeight() -> CGFloat {
        let numberOfCharacterLanes = characters.count
        let generalEventsLanePresent = !events.isEmpty || !characterArcs.isEmpty || characters.isEmpty
        let numberOfVisualLanes = numberOfCharacterLanes + (generalEventsLanePresent ? 1 : 0)
        
        let totalLanesHeight = CGFloat(max(1, numberOfVisualLanes)) * laneHeight
        return totalLanesHeight + topOffsetForTimeAxis + 50
    }
    
    private func findYPositionForEvent(_ event: EventItem, onCharacter character: CharacterItem?, charIndices: [UUID: Int], eventHeight: CGFloat) -> CGFloat {
        let laneCenterY = laneHeight / 2
        let eventBlockCenterY = eventHeight / 2
        let yOffsetInLane = laneCenterY - eventBlockCenterY
        
        if let char = character, let charID = char.id, let charIndex = charIndices[charID] {
            return topOffsetForTimeAxis + (CGFloat(charIndex) * laneHeight) + yOffsetInLane
        } else {
            return topOffsetForTimeAxis + (CGFloat(characters.count) * laneHeight) + yOffsetInLane
        }
    }
} // End of TimelineView struct

// MARK: - Nested EventBlockView (Ensure this is your latest enhanced version)
struct EventBlockView: View {
    @ObservedObject var event: EventItem
    let displayCharacter: CharacterItem?
    let pixelsPerDay: CGFloat
    let instantaneousEventWidth: CGFloat
    let currentXPosition: CGFloat
    let timelineStartDate: Date
    let yPosition: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let isBeingActivelyDragged: Bool
    let onTap: () -> Void
    let onDragStateChanged: (Bool, Date?, Date?) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var localIsDragging: Bool = false
    @State private var originalDateOnDragStart: Date?

    private var eventBackgroundColor: Color {
        if let hex = event.eventColorHex, let color = Color(hex: hex) {
            return color
        }
        if let char = displayCharacter, let hex = char.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var shortDescription: String? {
        guard let desc = event.eventDescription, !desc.isEmpty else { return nil }
        let lines = desc.components(separatedBy: .newlines) // Changed from split(separator:)
        return lines.first
    }
    
    private var displayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }

    var body: some View {
        let currentEventWidth = calculateEventWidth()
        let positioningX = currentXPosition + (currentEventWidth / 2) + dragTranslation.width

        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "Untitled Event")
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
            
            if let date = event.eventDate, currentEventWidth > 40 {
                Text(displayDateFormatter.string(from: date))
                    .font(.system(size: 8))
                    .opacity(0.8)
            }

            if let shortDesc = shortDescription, currentEventWidth > 60 {
                Text(shortDesc)
                    .font(.system(size: 8))
                    .lineLimit(event.durationDays > 0 ? 2 : 1)
                    .opacity(0.7)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 5, bottom: 4, trailing: 5))
        .frame(width: currentEventWidth, height: height, alignment: .topLeading)
        .background(eventBackgroundColor.opacity(localIsDragging || isBeingActivelyDragged ? 0.7 : 1.0))
        .foregroundColor(eventBackgroundColor.isLight() ? .black : .white) // Make sure Color+Extensions.isLight() exists
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.blue.opacity(0.8) : Color.black.opacity(0.3), lineWidth: isSelected ? 2.5 : 0.7)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .scaleEffect(isSelected ? 1.03 : (localIsDragging || isBeingActivelyDragged ? 1.01 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected || localIsDragging || isBeingActivelyDragged)
        .position(x: positioningX , y: yPosition)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !localIsDragging {
                        originalDateOnDragStart = event.eventDate
                        localIsDragging = true
                    }
                    let daysDragged = round(value.translation.width / pixelsPerDay)
                    if let capturedOriginalDate = originalDateOnDragStart {
                        let provisionalNewDate = Calendar.current.date(byAdding: .day, value: Int(daysDragged), to: capturedOriginalDate)
                        self.onDragStateChanged(true, capturedOriginalDate, provisionalNewDate)
                    }
                }
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    if let capturedOriginalDate = originalDateOnDragStart {
                        let daysDragged = round(value.translation.width / pixelsPerDay)
                        let finalNewDate = Calendar.current.date(byAdding: .day, value: Int(daysDragged), to: capturedOriginalDate)
                        
                        DispatchQueue.main.async {
                            event.eventDate = finalNewDate
                            do {
                                if viewContext.hasChanges {
                                    try viewContext.save()
                                }
                            } catch {
                                let nsError = error as NSError
                                print("Error saving dragged event: \(nsError), \(nsError.userInfo)")
                                event.eventDate = capturedOriginalDate
                            }
                            self.onDragStateChanged(false, capturedOriginalDate, finalNewDate)
                        }
                    }
                    self.localIsDragging = false
                    self.originalDateOnDragStart = nil
                }
        )
    }
    
    private func calculateEventWidth() -> CGFloat {
        if event.durationDays == 0 {
            return instantaneousEventWidth
        } else {
            return max(CGFloat(event.durationDays) * pixelsPerDay, instantaneousEventWidth * 2)
        }
    }
}

// MARK: - Other Nested Views (CharacterArcView, TimeAxisView)
// These are assumed to be the same as your existing versions.

struct CharacterArcView: View {
    @ObservedObject var arc: CharacterArcItem
    let startX: CGFloat
    let endX: CGFloat
    let peakX: CGFloat?
    let yPosition: CGFloat
    let height: CGFloat
    let peakIndicatorHeight: CGFloat
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let arcWidth = max(5, endX - startX)

        return ZStack(alignment: .leading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: height / 2))
                path.addLine(to: CGPoint(x: arcWidth, y: height / 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: isSelected ? height + 2 : height, lineCap: .butt))
            .frame(width: arcWidth)
            .overlay(
                RoundedRectangle(cornerRadius: height / 2)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
            
            if arcWidth > 20 {
                Text(arc.name ?? "Arc")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isSelected ? .black : (color.isLight() ? color.darker(by: 0.6) : color.darker(by:0.4)))
                    .padding(.horizontal, 2)
                    .lineLimit(1)
                    .frame(maxWidth: arcWidth - 4, alignment: .center)
            }

            if let pkX = peakX {
                let relativePeakX = pkX - startX
                if relativePeakX >= 0 && relativePeakX <= arcWidth {
                    Path { path in
                        path.move(to: CGPoint(x: relativePeakX, y: (height / 2) - (peakIndicatorHeight / 2)))
                        path.addLine(to: CGPoint(x: relativePeakX, y: (height / 2) + (peakIndicatorHeight / 2)))
                    }
                    .stroke((color.isLight() ? color.darker(by: 0.5) : color.darker(by: 0.3)), style: StrokeStyle(lineWidth: 2.5, dash: [2,2]))
                }
            }
        }
        .frame(width: arcWidth, height: max(height, peakIndicatorHeight))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(), value: isSelected)
        .position(x: startX + arcWidth / 2, y: yPosition)
    }
}

struct TimeAxisView: View {
    let startDate: Date
    let endDate: Date
    let totalWidth: CGFloat
    let offsetX: CGFloat
    let pixelsPerDay: CGFloat
    
    private var calendar = Calendar.current

    init(startDate: Date, endDate: Date, totalWidth: CGFloat, offsetX: CGFloat, pixelsPerDay: CGFloat) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalWidth = totalWidth
        self.offsetX = offsetX
        self.pixelsPerDay = pixelsPerDay
    }

    private var totalDays: Int {
        max(0, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
    }

    var body: some View {
        GeometryReader { geometryInternal in
            Path { path in
                path.move(to: CGPoint(x: offsetX, y: geometryInternal.size.height / 2))
                path.addLine(to: CGPoint(x: offsetX + totalWidth, y: geometryInternal.size.height / 2))

                if totalDays >= 0 {
                    for dayOffset in 0...totalDays {
                        let xPosInView = offsetX + CGFloat(dayOffset) * pixelsPerDay
                        if xPosInView >= offsetX && xPosInView <= offsetX + totalWidth + (pixelsPerDay / 2) {
                            path.move(to: CGPoint(x: xPosInView, y: geometryInternal.size.height / 2 - 5))
                            path.addLine(to: CGPoint(x: xPosInView, y: geometryInternal.size.height / 2 + 5))
                        }
                    }
                }
            }
            .stroke(Color.gray, lineWidth: 1)

            if totalDays >= 0 {
                ForEach(0...totalDays, id: \.self) { dayOffset in
                    if let dateForLabel = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                        let xPosInView = offsetX + CGFloat(dayOffset) * pixelsPerDay
                        let labelFrequency = max(1, Int(80 / max(1,pixelsPerDay)))
                        
                        if dayOffset % labelFrequency == 0 && xPosInView >= offsetX && xPosInView <= offsetX + totalWidth {
                            Text(dateFormatterForAxis.string(from: dateForLabel))
                                .font(.caption2)
                                .position(x: xPosInView, y: geometryInternal.size.height / 2 + 15)
                                .fixedSize()
                        }
                    }
                }
            }
        }
    }
    
    private var dateFormatterForAxis: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project"
        
        let char1 = CharacterItem(context: context); char1.id = UUID(); char1.name = "Alice"; char1.colorHex = "#E91E63"; char1.project = sampleProject
        
        let event1 = EventItem(context: context); event1.id = UUID(); event1.title = "Event 1: Long Title to Test Display"; event1.eventDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()); event1.durationDays = 2; event1.project = sampleProject; event1.eventDescription = "Desc line 1.\nDesc line 2."; event1.eventColorHex = "#3498DB"; event1.addToParticipatingCharacters(char1)
        let event2 = EventItem(context: context); event2.id = UUID(); event2.title = "Event 2"; event2.eventDate = Calendar.current.date(byAdding: .day, value: 4, to: Date()); event2.durationDays = 0; event2.project = sampleProject;

        return TimelineView(project: sampleProject, selection: .constant(.timeline))
            .environment(\.managedObjectContext, context)
            .frame(width: 800, height: 600)
    }
}
