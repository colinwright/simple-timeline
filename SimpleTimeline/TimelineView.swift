import SwiftUI
import CoreData

// Ensure Color extensions are accessible (e.g., in Color+Extensions.swift)

struct TimelineView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext

    // Fetched Results
    @FetchRequest private var events: FetchedResults<EventItem>
    @FetchRequest private var characters: FetchedResults<CharacterItem>
    @FetchRequest private var characterArcs: FetchedResults<CharacterArcItem>

    // Timeline drawing constants
    private let eventHeight: CGFloat = 20
    private let arcHeight: CGFloat = 10
    private let peakIndicatorHeight: CGFloat = 14
    private let eventSpacing: CGFloat = 5
    private let horizontalPadding: CGFloat = 20
    private let characterLaneHeaderWidth: CGFloat = 150
    private let laneHeight: CGFloat = 40
    private let instantaneousEventWidth: CGFloat = 8
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
    
    // State to manage the event being actively dragged
    @State private var activelyDraggingEventID: UUID?
    @State private var originalDateForDraggedEvent: Date?

    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
        
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
            print("Deselecting all timeline items via background tap.")
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

    // MARK: - Body and Main Subviews
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
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: selectedEventForDetail != nil || selectedArcForDetail != nil)
            }
        }
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading) {
            timelineHeader
            
            if characters.isEmpty && events.isEmpty && characterArcs.isEmpty {
                 Text("No data to display on the timeline.")
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
                 Text("Add events or characters to see the timeline.")
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

    private var timelineHeader: some View {
        HStack {
            Text("Timeline for: \(project.title ?? "Untitled Project")")
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut) {
                    currentPixelsPerDay = min(maxPixelsPerDay, currentPixelsPerDay * zoomFactor)
                }
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .keyboardShortcut("+", modifiers: .command)

            Button {
                 withAnimation(.easeInOut) {
                    currentPixelsPerDay = max(absoluteMinPixelsPerDay, currentPixelsPerDay / zoomFactor)
                }
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .keyboardShortcut("-", modifiers: .command)
        }
        .padding([.leading, .top, .trailing])
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
        let totalWidthForZStack = actualTimelineContentWidth + characterLaneHeaderWidth + (horizontalPadding * 2)

        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                tappableBackgroundLayer(totalWidth: totalWidthForZStack, totalHeight: calculateTotalHeight())
                characterLaneVisualsLayer(totalWidth: totalWidthForZStack) // Pass charIndices if needed by this layer in future
                eventLayer(currentRange: currentRange, effectivePixelsPerDay: effectivePixelsPerDay, charIndices: charIndices)
                characterArcLayer(currentRange: currentRange, effectivePixelsPerDay: effectivePixelsPerDay, charIndices: charIndices)
                timeAxisLayer(currentRange: currentRange, actualTimelineContentWidth: actualTimelineContentWidth, effectivePixelsPerDay: effectivePixelsPerDay)
            }
            .frame(width: totalWidthForZStack, height: calculateTotalHeight())
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
    private func characterLaneVisualsLayer(totalWidth: CGFloat) -> some View { // Removed charIndices from parameters
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
            if !events.isEmpty {
                HStack {
                     Text(characters.isEmpty ? "Events" : "General Events")
                        .font(.caption).padding(5)
                        .frame(width: characterLaneHeaderWidth - 10, height: laneHeight, alignment: .leading)
                        .background((characters.count).isMultiple(of: 2) ? Color.gray.opacity(0.1) : Color.clear)
                    Spacer()
                }
                .frame(width: totalWidth, height: laneHeight)
                if !characters.isEmpty {
                     Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1).offset(x: characterLaneHeaderWidth)
                }
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
                        yPosition: findYPositionForEvent(event, onCharacter: nil, charIndices: charIndices),
                        height: eventHeight,
                        isSelected: self.selectedEventForDetail?.id == event.id,
                        isBeingActivelyDragged: self.activelyDraggingEventID == event.id,
                        onTap: {
                            self.selectedArcForDetail = nil
                            self.selectedEventForDetail = (self.selectedEventForDetail?.id == event.id ? nil : event)
                            self.activelyDraggingEventID = nil; self.originalDateForDraggedEvent = nil
                        },
                        onDragStateChanged: { dragging, originalDate, newDate in
                            // Corrected argument label: newProvisionalDate instead of provisionalDate
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
                            yPosition: findYPositionForEvent(event, onCharacter: character, charIndices: charIndices),
                            height: eventHeight,
                            isSelected: self.selectedEventForDetail?.id == event.id,
                            isBeingActivelyDragged: self.activelyDraggingEventID == event.id,
                            onTap: {
                                self.selectedArcForDetail = nil
                                self.selectedEventForDetail = (self.selectedEventForDetail?.id == event.id ? nil : event)
                                self.activelyDraggingEventID = nil; self.originalDateForDraggedEvent = nil
                            },
                            onDragStateChanged: { dragging, originalDate, newDate in
                                // Corrected argument label: newProvisionalDate instead of provisionalDate
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
            if let char = arc.character, let charID = char.id,let charIndex = charIndices[charID],
               let startEvent = arc.startEvent, let startDate = startEvent.eventDate,
               let endEventUnwrapped = arc.endEvent, let endDate = endEventUnwrapped.eventDate {
                let arcStartX = xPosition(for: startDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                let endEventActualEndDate = Calendar.current.date(byAdding: .day, value: Int(endEventUnwrapped.durationDays), to: endDate) ?? endDate
                let arcEndX = xPosition(for: endEventActualEndDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                let peakX: CGFloat? = { if let peakEvent = arc.peakEvent, let peakDate = peakEvent.eventDate {
                        return xPosition(for: peakDate, timelineStartDate: currentRange.start, currentPixelsPerDay: effectivePixelsPerDay)
                    } ; return nil }()
                let arcYPosition = topOffsetForTimeAxis + (CGFloat(charIndex) * laneHeight) + (laneHeight * 0.65)
                CharacterArcView( arc: arc, startX: arcStartX, endX: arcEndX, peakX: peakX,
                    yPosition: arcYPosition, height: arcHeight, peakIndicatorHeight: peakIndicatorHeight,
                    color: Color(hex: char.colorHex ?? "") ?? .purple.opacity(0.7),
                    isSelected: self.selectedArcForDetail?.id == arc.id,
                    onTap: { self.selectedEventForDetail = nil; self.selectedArcForDetail = (self.selectedArcForDetail?.id == arc.id ? nil : arc) }
                ).zIndex(1)
            }
        }
    }

    @ViewBuilder
    private func timeAxisLayer(currentRange: (start: Date, end: Date), actualTimelineContentWidth: CGFloat, effectivePixelsPerDay: CGFloat) -> some View {
        TimeAxisView(startDate: currentRange.start, endDate: currentRange.end,
                     totalWidth: actualTimelineContentWidth, offsetX: 0, pixelsPerDay: effectivePixelsPerDay)
            .frame(height: 40).padding(.horizontal, horizontalPadding).offset(x: characterLaneHeaderWidth, y: 10)
            .zIndex(3)
    }
    
    private func xPosition(for date: Date, timelineStartDate: Date, currentPixelsPerDay: CGFloat) -> CGFloat {
        let daysFromStart = Calendar.current.dateComponents([.day], from: timelineStartDate, to: date).day ?? 0
        return characterLaneHeaderWidth + CGFloat(daysFromStart) * currentPixelsPerDay + horizontalPadding
    }

    private func calculateTotalHeight() -> CGFloat {
        let numberOfVisualLanes = characters.count + (!events.isEmpty ? 1 : 0)
        let totalLanesHeight = CGFloat(max(1, numberOfVisualLanes)) * laneHeight
        return totalLanesHeight + topOffsetForTimeAxis + 50
    }
    
    private func findYPositionForEvent(_ event: EventItem, onCharacter character: CharacterItem?, charIndices: [UUID: Int]) -> CGFloat {
        let eventYOffsetInLane = laneHeight * 0.30
        if let char = character, let charID = char.id, let charIndex = charIndices[charID] {
            return topOffsetForTimeAxis + (CGFloat(charIndex) * laneHeight) + eventYOffsetInLane
        } else {
            return topOffsetForTimeAxis + (CGFloat(characters.count) * laneHeight) + eventYOffsetInLane
        }
    }
}

// EventBlockView, CharacterArcView, TimeAxisView, and PreviewProvider structs remain the same
// ... (Ensure these are correctly defined in your file or accessible)

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
                    .foregroundColor(isSelected ? .black : color.darker(by:0.4))
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
                    .stroke(color.darker(by: 0.3), style: StrokeStyle(lineWidth: 2.5, dash: [2,2]))
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

    var body: some View {
        let currentEventWidth = calculateEventWidth()
        let visualXPosition = currentXPosition + dragTranslation.width

        VStack(alignment: .leading) {
            Text(event.title ?? "Untitled Event")
                .font(.system(size: 10))
                .lineLimit(1)
                .padding(EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3))
                .frame(width: max(currentEventWidth - 2, 1), height: height - 2)
                .background(getEventColor().opacity(localIsDragging || isBeingActivelyDragged ? 0.7 : 1.0))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.yellow : Color.black.opacity(0.5), lineWidth: isSelected ? 2 : 0.5)
                )
        }
        .frame(width: currentEventWidth, height: height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .scaleEffect(isSelected ? 1.1 : (localIsDragging || isBeingActivelyDragged ? 1.05 : 1.0))
        .animation(.spring(), value: isSelected || localIsDragging || isBeingActivelyDragged)
        .position(x: visualXPosition + (currentEventWidth / 2) , y: yPosition)
        .gesture(
            DragGesture()
                .onChanged { value in
                    self.localIsDragging = true
                    if self.originalDateOnDragStart == nil {
                        self.originalDateOnDragStart = event.eventDate
                    }
                    let daysDragged = round(value.translation.width / pixelsPerDay)
                    if let originalDate = self.originalDateOnDragStart {
                        let provisionalNewDate = Calendar.current.date(byAdding: .day, value: Int(daysDragged), to: originalDate)
                        if event.eventDate != provisionalNewDate {
                           event.eventDate = provisionalNewDate
                        }
                        self.onDragStateChanged(true, self.originalDateOnDragStart, provisionalNewDate)
                    }
                }
                .updating($dragTranslation) { value, state, transaction in
                    state = value.translation
                }
                .onEnded { value in
                    self.localIsDragging = false
                    if let originalDate = self.originalDateOnDragStart {
                        let daysDragged = round(value.translation.width / pixelsPerDay)
                        let finalNewDate = Calendar.current.date(byAdding: .day, value: Int(daysDragged), to: originalDate)
                        
                        DispatchQueue.main.async {
                            event.eventDate = finalNewDate
                            do {
                                if viewContext.hasChanges {
                                    try viewContext.save()
                                    print("Event '\(event.title ?? "")' moved to \(finalNewDate?.description ?? "N/A") and saved.")
                                }
                            } catch {
                                let nsError = error as NSError
                                print("Error saving dragged event: \(nsError), \(nsError.userInfo)")
                                event.eventDate = originalDate
                            }
                            self.onDragStateChanged(false, self.originalDateOnDragStart, finalNewDate)
                        }
                    }
                    self.originalDateOnDragStart = nil
                }
        )
    }
    
    private func calculateEventWidth() -> CGFloat {
        if event.durationDays == 0 {
            return instantaneousEventWidth
        } else {
            return max(CGFloat(event.durationDays) * pixelsPerDay, pixelsPerDay)
        }
    }
    
    private func getEventColor() -> Color {
        if let char = displayCharacter, let hex = char.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .gray
    }
}

// TimeAxisView and PreviewProvider structs remain the same
// ...
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
        calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
    }

    var body: some View {
        GeometryReader { geometryInternal in
            Path { path in
                path.move(to: CGPoint(x: offsetX, y: geometryInternal.size.height / 2))
                path.addLine(to: CGPoint(x: offsetX + totalWidth, y: geometryInternal.size.height / 2))

                for dayOffset in 0...totalDays {
                    let xPosInView = offsetX + CGFloat(dayOffset) * pixelsPerDay
                    if xPosInView >= offsetX && xPosInView <= offsetX + totalWidth + (pixelsPerDay / 2) {
                        path.move(to: CGPoint(x: xPosInView, y: geometryInternal.size.height / 2 - 5))
                        path.addLine(to: CGPoint(x: xPosInView, y: geometryInternal.size.height / 2 + 5))
                    }
                }
            }
            .stroke(Color.gray, lineWidth: 1)

            ForEach(0...totalDays, id: \.self) { dayOffset in
                if let dateForLabel = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                    let xPosInView = offsetX + CGFloat(dayOffset) * pixelsPerDay
                    let labelFrequency = max(1, Int(60 / max(1,pixelsPerDay)))
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
        sampleProject.title = "Sample Project for Timeline"
        sampleProject.id = UUID()
        sampleProject.creationDate = Date()

        let char1 = CharacterItem(context: context); char1.name = "Alice"; char1.colorHex = "#E91E63"; char1.project = sampleProject; char1.id = UUID()
        let char2 = CharacterItem(context: context); char2.name = "Bob"; char2.colorHex = "#4CAF50"; char2.project = sampleProject; char2.id = UUID()
        let char3 = CharacterItem(context: context); char3.name = "Charlie"; char3.colorHex = "#FFC107"; char3.project = sampleProject; char3.id = UUID()
        let today = Date(); let calendar = Calendar.current
        let eventStart = calendar.date(byAdding: .day, value: 1, to: today)!
        let eventPeak = calendar.date(byAdding: .day, value: 4, to: today)!
        let eventEndForArc = calendar.date(byAdding: .day, value: 7, to: today)!
        let evS = EventItem(context: context); evS.title = "Arc Start"; evS.eventDate = eventStart; evS.durationDays = 0; evS.project = sampleProject; evS.id = UUID()
        let evP = EventItem(context: context); evP.title = "Arc Peak"; evP.eventDate = eventPeak; evP.durationDays = 1; evP.project = sampleProject; evS.participatingCharacters = NSSet(array: [char1]); evP.id = UUID()
        let evE = EventItem(context: context); evE.title = "Arc End"; evE.eventDate = eventEndForArc; evE.durationDays = 2; evE.project = sampleProject; evE.id = UUID()
        let sampleArc = CharacterArcItem(context: context); sampleArc.name = "Alice's Arc"; sampleArc.id = UUID(); sampleArc.creationDate = Date()
        sampleArc.project = sampleProject; sampleArc.character = char1; sampleArc.startEvent = evS; sampleArc.peakEvent = evP; sampleArc.endEvent = evE
        let eventOther = EventItem(context: context)
        eventOther.title="Bob's Task"; eventOther.eventDate=calendar.date(byAdding: .day, value: 2, to: today)!
        eventOther.durationDays=3; eventOther.project=sampleProject; eventOther.id = UUID()
        eventOther.participatingCharacters = NSSet(array: [char2])

        return TimelineView(project: sampleProject)
            .environment(\.managedObjectContext, context)
            .frame(width: 800, height: 500)
    }
}
