import SwiftUI
import CoreData
import Combine // Required for .onReceive

struct TimelineView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selection: MainViewSelection

    // Fetched Results
    @FetchRequest private var events: FetchedResults<EventItem>
    @FetchRequest private var characters: FetchedResults<CharacterItem>
    @FetchRequest private var characterArcs: FetchedResults<CharacterArcItem>

    // For Event Type Lanes
    @State private var eventTypesForLanes: [String] = []
    @State private var eventTypeIndices: [String: Int] = [:]
    private let unclassifiedEventsLaneName = "Uncategorized"
    private let eventTypeLaneHeaderWidth: CGFloat = 150

    // Timeline drawing constants
    private let eventBlockBaseHeight: CGFloat = 75
    private let arcHeight: CGFloat = 8
    private let peakIndicatorHeight: CGFloat = 12
    private let horizontalPadding: CGFloat = 20
    private let laneHeight: CGFloat = 85
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

    // State for selected items
    @State private var selectedEventForDetail: EventItem?
    @State private var selectedArcForDetail: CharacterArcItem?
    @State private var activelyDraggingEventID: UUID?

    init(project: ProjectItem, selection: Binding<MainViewSelection>) {
        self.project = project
        self._selection = selection

        let projectPredicate = NSPredicate(format: "project == %@", project)
        
        self._events = FetchRequest<EventItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \EventItem.eventDate, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        self._characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
        
        self._characterArcs = FetchRequest<CharacterArcItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterArcItem.name, ascending: true)],
            predicate: projectPredicate,
            animation: .default
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            timelinePanel
            if selectedEventForDetail != nil {
                TimelineItemDetailView(
                    project: project,
                    selectedEvent: $selectedEventForDetail,
                    selectedArc: .constant(nil),
                    provisionalEventDateOverride: (selectedEventForDetail?.id == activelyDraggingEventID ? selectedEventForDetail?.eventDate : nil)
                )
                .frame(width: detailPanelWidth)
                .layoutPriority(1)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: selectedEventForDetail != nil || activelyDraggingEventID != nil)
            }
        }
        .onAppear {
            buildEventTypeLanesAndIndices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification, object: viewContext)) { notification in
            var rebuildLanes = false
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
               updatedObjects.contains(where: { $0 is EventItem }) {
                rebuildLanes = true
            }
            if !rebuildLanes, let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>,
               insertedObjects.contains(where: { $0 is EventItem }) {
                rebuildLanes = true
            }
            if !rebuildLanes, let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
               deletedObjects.contains(where: { $0 is EventItem }) {
                rebuildLanes = true
            }

            if rebuildLanes {
                buildEventTypeLanesAndIndices()
            }
        }
    }

    private var timelinePanel: some View {
        ZStack {
            // This is the primary background tap catcher for the entire panel.
            // It's at the bottom of the ZStack.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // print("TimelinePanel root ZStack background tapped") // Debug
                    deselectAllItems()
                }

            // All other content of the panel is in this VStack, drawn on top.
            VStack(alignment: .leading, spacing: 8) {
                DetailViewHeader {
                    BreadcrumbView(
                        projectTitle: project.title ?? "Untitled Project",
                        currentViewName: "Timeline",
                        isProjectTitleClickable: true,
                        projectHomeAction: { selection = .projectHome }
                    )
                } trailing: {
                    HStack {
                        Button { addNewEvent() } label: { Label("Add Event", systemImage: "plus.circle.fill").labelStyle(.iconOnly) }.help("Add New Event")
                        Button { withAnimation(.easeInOut) { currentPixelsPerDay = min(maxPixelsPerDay, currentPixelsPerDay * zoomFactor) } } label: { Label("Zoom In", systemImage: "plus.magnifyingglass").labelStyle(.iconOnly) }.keyboardShortcut("+", modifiers: .command).help("Zoom In")
                        Button { withAnimation(.easeInOut) { currentPixelsPerDay = max(absoluteMinPixelsPerDay, currentPixelsPerDay / zoomFactor) } } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass").labelStyle(.iconOnly) }.keyboardShortcut("-", modifiers: .command).help("Zoom Out")
                    }
                }
                
                if events.isEmpty && eventTypesForLanes.isEmpty {
                     Text("No events. Add an event to start your timeline.")
                        .foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).padding()
                } else if let currentRange = dateRange {
                    GeometryReader { geometry in
                        timelineScrollableContent(currentRange: currentRange, geometry: geometry)
                    }
                } else {
                     Text("Add events with dates to build the timeline.")
                        .foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // By default, this VStack should allow taps on its transparent areas
            // to pass through to the Color.clear layer behind it.
        }
    }
    
    // MARK: - Data Handling & Calculations
    private func buildEventTypeLanesAndIndices() {
        let typesFromEvents = Set(events.compactMap { $0.type?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty() })
        var sortedUniqueTypes = Array(typesFromEvents).sorted()
        let hasEventsWithNoTypeOrEmptyType = events.contains { $0.type == nil || $0.type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true }
        if hasEventsWithNoTypeOrEmptyType || (sortedUniqueTypes.isEmpty && !events.isEmpty) {
            if !sortedUniqueTypes.contains(unclassifiedEventsLaneName) { sortedUniqueTypes.append(unclassifiedEventsLaneName) }
        }
        if events.isEmpty { sortedUniqueTypes = [] }
        self.eventTypesForLanes = sortedUniqueTypes
        var indices: [String: Int] = [:]; self.eventTypesForLanes.enumerated().forEach { indices[$1] = $0 }; self.eventTypeIndices = indices
    }
        
    private var dateRange: (start: Date, end: Date)? {
        var allDates: [Date] = []; let calendar = Calendar.current
        events.forEach { event in if let date = event.eventDate { allDates.append(date); allDates.append(calendar.date(byAdding: .day, value: Int(event.durationDays), to: date) ?? date) } }
        characterArcs.forEach { arc in
            if let startDate = arc.startEvent?.eventDate { allDates.append(startDate) }
            if let peakDate = arc.peakEvent?.eventDate { allDates.append(peakDate) }
            if let endDate = arc.endEvent?.eventDate { allDates.append(endDate); allDates.append(calendar.date(byAdding: .day, value: Int(arc.endEvent?.durationDays ?? 0), to: endDate) ?? endDate) }
        }
        guard !allDates.isEmpty else { let today = Date(); return (calendar.date(byAdding: .day, value: -1, to: today)!, calendar.date(byAdding: .day, value: 29, to: today)!) }
        let minDate = allDates.min()!; let maxDate = allDates.max()!
        let paddedStartDate = calendar.date(byAdding: .day, value: -2, to: minDate)!
        var paddedEndDate = calendar.date(byAdding: .day, value: 2, to: maxDate)!
        if let daysBetween = calendar.dateComponents([.day], from: paddedStartDate, to: paddedEndDate).day, daysBetween < 7 { paddedEndDate = calendar.date(byAdding: .day, value: 7 - daysBetween, to: paddedEndDate)! }
        if paddedStartDate >= paddedEndDate { paddedEndDate = calendar.date(byAdding: .day, value: 7, to: paddedStartDate)! }
        return (paddedStartDate, paddedEndDate)
    }

    private func calculateTotalTimelineContentWidth(for range: (start: Date, end: Date), pixelsPerDayToUse: CGFloat) -> CGFloat {
        CGFloat(max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1)) * pixelsPerDayToUse
    }

    private func xPosition(for date: Date, timelineStartDate: Date, currentPixelsPerDay: CGFloat) -> CGFloat {
        eventTypeLaneHeaderWidth + CGFloat(Calendar.current.dateComponents([.day], from: timelineStartDate, to: date).day ?? 0) * currentPixelsPerDay + horizontalPadding
    }

    private func findYPositionForEvent(eventType: String, eventHeight: CGFloat) -> CGFloat {
        let laneIndex = eventTypeIndices[eventType] ?? eventTypesForLanes.firstIndex(of: unclassifiedEventsLaneName) ?? (eventTypesForLanes.indices.last ?? 0)
        let laneTopY = topOffsetForTimeAxis + (CGFloat(laneIndex) * laneHeight)
        return laneTopY + (laneHeight / 2)
    }

    private func calculateTotalHeight() -> CGFloat {
        let numberOfVisualLanes = max(1, eventTypesForLanes.count)
        let totalLanesHeight = CGFloat(numberOfVisualLanes) * laneHeight
        return totalLanesHeight + topOffsetForTimeAxis + 50
    }

    // MARK: - UI Actions
    private func addNewEvent() {
        withAnimation {
            let newEvent = EventItem(context: viewContext); newEvent.id = UUID(); newEvent.title = "New Event"
            if let currentTimelineRange = dateRange { let calendar = Calendar.current
                newEvent.eventDate = calendar.date(byAdding: .day, value: (calendar.dateComponents([.day], from: currentTimelineRange.start, to: currentTimelineRange.end).day ?? 0) / 2, to: currentTimelineRange.start) ?? Date()
            } else { newEvent.eventDate = Date() }
            newEvent.durationDays = 0; newEvent.project = self.project; newEvent.summaryLine = nil; newEvent.type = nil
            self.selectedArcForDetail = nil; self.selectedEventForDetail = newEvent; buildEventTypeLanesAndIndices()
        }
    }
    private func deselectAllItems() {
        if selectedEventForDetail != nil || activelyDraggingEventID != nil {
            withAnimation(.easeInOut(duration: 0.1)) { self.selectedEventForDetail = nil; self.activelyDraggingEventID = nil }
        }
    }
    private func handleEventDragStateChange(event: EventItem, isDragging: Bool, originalDragStartDate: Date?, currentProvisionalOrFinalDate: Date?) {
        if isDragging { self.activelyDraggingEventID = event.id; if self.selectedEventForDetail?.id != event.id { self.selectedArcForDetail = nil; self.selectedEventForDetail = event }
        } else { self.activelyDraggingEventID = nil; if let currentlySelected = self.selectedEventForDetail, currentlySelected.id == event.id { let refreshedEvent = event; self.selectedEventForDetail = nil; DispatchQueue.main.async { self.selectedEventForDetail = refreshedEvent } } }
    }

    // MARK: - Scrollable Content & Layers
    @ViewBuilder
    private func timelineScrollableContent(currentRange: (start: Date, end: Date), geometry: GeometryProxy) -> some View {
        let availableWidthForContent = geometry.size.width - eventTypeLaneHeaderWidth - (horizontalPadding * 2)
        let durationInDaysForRange = CGFloat(max(1, Calendar.current.dateComponents([.day], from: currentRange.start, to: currentRange.end).day ?? 1))
        let minPixelsPerDayToFill = (availableWidthForContent > 0 && durationInDaysForRange > 0) ? (availableWidthForContent / durationInDaysForRange) : absoluteMinPixelsPerDay
        let effectivePixelsPerDay = max(currentPixelsPerDay, minPixelsPerDayToFill, absoluteMinPixelsPerDay)
        let actualTimelineContentWidth = calculateTotalTimelineContentWidth(for: currentRange, pixelsPerDayToUse: effectivePixelsPerDay)
        let totalWidthForZStack = max(geometry.size.width, actualTimelineContentWidth + eventTypeLaneHeaderWidth + (horizontalPadding * 2))
        let totalHeightForContent = calculateTotalHeight()

        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                eventTypeLaneVisualsLayer(totalWidth: totalWidthForZStack).zIndex(0)
                eventLayer(currentRange: currentRange, effectivePixelsPerDay: effectivePixelsPerDay).zIndex(1)
                timeAxisLayer(currentRange: currentRange, actualTimelineContentWidth: actualTimelineContentWidth, effectivePixelsPerDay: effectivePixelsPerDay).zIndex(2)
            }
            .frame(width: totalWidthForZStack, height: totalHeightForContent)
            .contentShape(Rectangle()) // This makes the background of the ZStack (scrollable content) tappable
            .onTapGesture {
                // print("ScrollView ZStack content area TAPPED - Deselecting All") // Debug
                deselectAllItems()
            }
            .gesture(MagnificationGesture().updating($magnifyBy) { c, g, _ in g = c }.onEnded { v in withAnimation(.easeInOut) { currentPixelsPerDay = max(absoluteMinPixelsPerDay, min(maxPixelsPerDay, currentPixelsPerDay * v)) } })
        }
    }

    @ViewBuilder
    private func eventTypeLaneVisualsLayer(totalWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<eventTypesForLanes.count, id: \.self) { index in
                let typeName = eventTypesForLanes[index]
                HStack(spacing: 0) {
                    Text(typeName).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                        .padding(.leading, 6).padding(.trailing, 4)
                        .frame(width: eventTypeLaneHeaderWidth, height: laneHeight, alignment: .leading)
                    Rectangle().fill(index.isMultiple(of: 2) ? Color.black.opacity(0.02) : Color.clear).frame(height: laneHeight)
                }.frame(width: totalWidth, height: laneHeight)
                Rectangle().fill(Color.gray.opacity(index == eventTypesForLanes.count - 1 ? 0.25 : 0.15))
                    .frame(width:totalWidth - eventTypeLaneHeaderWidth, height: 1).offset(x: eventTypeLaneHeaderWidth)
            }
        }.padding(.top, topOffsetForTimeAxis)
    }

    @ViewBuilder
    private func eventLayer(currentRange: (start: Date, end: Date), effectivePixelsPerDay: CGFloat) -> some View {
        ForEach(events) { event in renderEventBlock(for: event, in: currentRange, pixelsPerDay: effectivePixelsPerDay) }
    }

    @ViewBuilder
    private func renderEventBlock(for event: EventItem, in currentRange: (start: Date, end: Date), pixelsPerDay: CGFloat) -> some View {
        if let validEventDate = event.eventDate {
            let currentEventXPos = xPosition(for: validEventDate, timelineStartDate: currentRange.start, currentPixelsPerDay: pixelsPerDay)
            let trimmedEventType = event.type?.trimmingCharacters(in: .whitespacesAndNewlines)
            let eventTypeForLane = trimmedEventType?.nilIfEmpty() ?? unclassifiedEventsLaneName
            let yPos = findYPositionForEvent(eventType: eventTypeForLane, eventHeight: eventBlockBaseHeight)
            let isSelected = self.selectedEventForDetail?.id == event.id
            let isActivelyBeingDragged = self.activelyDraggingEventID == event.id

            EventBlockView( event: event, project: self.project, pixelsPerDay: pixelsPerDay,
                instantaneousEventWidth: instantaneousEventWidth, currentXPosition: currentEventXPos,
                timelineStartDate: currentRange.start, yPosition: yPos, height: eventBlockBaseHeight,
                isSelected: isSelected, isBeingActivelyDragged: isActivelyBeingDragged,
                onTap: { self.selectedEventForDetail = (isSelected ? nil : event); if !isSelected { self.activelyDraggingEventID = nil } },
                onDragStateChanged: { dragging, oD, nD in handleEventDragStateChange(event:event,isDragging:dragging,originalDragStartDate:oD,currentProvisionalOrFinalDate:nD) }
            ).environment(\.managedObjectContext, self.viewContext)
            .zIndex(isSelected || isActivelyBeingDragged ? 1.5 : 1.0)
        } else { EmptyView() }
    }

    @ViewBuilder
    private func timeAxisLayer(currentRange: (start: Date, end: Date), actualTimelineContentWidth: CGFloat, effectivePixelsPerDay: CGFloat) -> some View {
        TimeAxisView(startDate: currentRange.start, endDate: currentRange.end, totalWidth: actualTimelineContentWidth, offsetX: 0, pixelsPerDay: effectivePixelsPerDay)
            .frame(height: 40).padding(.horizontal, horizontalPadding).offset(x: eventTypeLaneHeaderWidth, y: 10)
    }
}

// MARK: - Nested EventBlockView
struct EventBlockView: View {
    @ObservedObject var event: EventItem; @ObservedObject var project: ProjectItem
    let pixelsPerDay: CGFloat, instantaneousEventWidth: CGFloat, currentXPosition: CGFloat
    let timelineStartDate: Date; let yPosition: CGFloat, height: CGFloat
    let isSelected: Bool, isBeingActivelyDragged: Bool
    let onTap: () -> Void; let onDragStateChanged: (Bool, Date?, Date?) -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @State private var localIsDragging: Bool = false; @State private var originalDateOnDragStart: Date?
    private var eventBlockBackgroundColor: Color { if let hex = event.eventColorHex, !hex.isEmpty, let color = Color(hex: hex) { return color }; return Color.blue.opacity(0.6) }
    private var displayDateFormatter: DateFormatter { let formatter = DateFormatter(); formatter.dateFormat = "MMM d"; return formatter }
    var body: some View {
        let currentEventWidth = calculateEventWidth(); let centerXPosition = currentXPosition + (currentEventWidth / 2)
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title ?? "Untitled Event").font(.system(size: 11, weight: .semibold)).lineLimit(1).padding(.bottom, 1)
            if let date = event.eventDate, currentEventWidth > 45 { Text(displayDateFormatter.string(from: date)).font(.system(size: 9, weight: .medium)).foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.6) ? .black.opacity(0.65) : .white.opacity(0.75)) }
            HStack(spacing: 6) {
                if let characters = event.participatingCharacters as? Set<CharacterItem>, !characters.isEmpty {
                    HStack(spacing: -4) {
                        ForEach(characters.sorted(by: { $0.name ?? "" < $1.name ?? "" }).prefix(5), id: \.self) { char in
                            Circle().fill(Color(hex: char.colorHex ?? "") ?? .gray).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(eventBlockBackgroundColor.isLight() ? Color.white.opacity(0.8) : Color.black.opacity(0.3) , lineWidth: 0.75))
                                .shadow(color: .black.opacity(0.2),radius: 0.5, x:0, y:0.5).help(char.name ?? "Unknown Character")
                        }
                        if characters.count > 5 { Text("+\(characters.count - 5)").font(.system(size: 8, weight: .semibold))
                            .foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.6) ? .black.opacity(0.7) : .white.opacity(0.8)).padding(.leading, 5) }
                    }
                } else { Spacer() }
                if let locationName = event.locationName?.trimmingCharacters(in: .whitespacesAndNewlines), !locationName.isEmpty, currentEventWidth > (((event.participatingCharacters as? Set<CharacterItem>)?.isEmpty ?? true) ? 80 : 120) {
                    if !((event.participatingCharacters as? Set<CharacterItem>)?.isEmpty ?? true) { Spacer() }
                    HStack(spacing: 2) { Image(systemName: "mappin.and.ellipse").font(.system(size: 9)).foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.6) ? .black.opacity(0.6) : .white.opacity(0.7))
                        Text(locationName).font(.system(size: 9)).foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.6) ? .black.opacity(0.6) : .white.opacity(0.7)).lineLimit(1).truncationMode(.tail)
                    }
                } else { if ((event.participatingCharacters as? Set<CharacterItem>)?.isEmpty ?? true) { Spacer() } }
            }.frame(height: 12)
            let summaryToShow = event.summaryLine?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty() ?? event.eventDescription?.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty() ?? ""
            if !summaryToShow.isEmpty, currentEventWidth > 25 { Text(summaryToShow).font(.system(size: 9)).lineLimit(height > 65 ? 2 : 1).truncationMode(.tail).foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.6) ? .black.opacity(0.75) : .white.opacity(0.85)).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 5, leading: 7, bottom: 5, trailing: 7))
        .frame(width: currentEventWidth, height: height, alignment: .topLeading)
        .background(eventBlockBackgroundColor.opacity(localIsDragging || isBeingActivelyDragged ? 0.8 : 1.0))
        .foregroundColor(eventBlockBackgroundColor.isLight(threshold: 0.55) ? .black.opacity(0.9) : .white.opacity(0.95))
        .cornerRadius(7)
        .shadow(color: Color.black.opacity(isSelected || localIsDragging || isBeingActivelyDragged ? 0.25 : 0.15), radius: isSelected ? 3 : 2, x: 0, y: isSelected ? 2 : 1.5)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isSelected ? Color.accentColor : Color.black.opacity(0.25), lineWidth: isSelected ? 2 : 0.75))
        .contentShape(Rectangle()).onTapGesture(perform: onTap)
        .scaleEffect(isSelected || localIsDragging || isBeingActivelyDragged ? 1.015 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected || localIsDragging || isBeingActivelyDragged)
        .position(x: centerXPosition , y: yPosition)
        .gesture(
            DragGesture()
                .onChanged { value in if !localIsDragging { originalDateOnDragStart = event.eventDate; localIsDragging = true }; let days = round(value.translation.width / pixelsPerDay); if let oD = originalDateOnDragStart { let nD = Calendar.current.date(byAdding: .day, value: Int(days), to: oD)!; event.eventDate = nD; self.onDragStateChanged(true, oD, nD) } }
                .onEnded { value in localIsDragging = false; if let oD = originalDateOnDragStart { let days = round(value.translation.width / pixelsPerDay); let fD = Calendar.current.date(byAdding: .day, value: Int(days), to: oD)!; event.eventDate = fD; DispatchQueue.main.async { do { if viewContext.hasChanges { try viewContext.save() }; self.onDragStateChanged(false, oD, event.eventDate) } catch { print("Err saving: \(error.localizedDescription)"); event.eventDate = oD; self.onDragStateChanged(false, oD, oD) } } }; originalDateOnDragStart = nil }
        )
    }
    private func calculateEventWidth() -> CGFloat {
        if event.durationDays == 0 { return max(instantaneousEventWidth, CGFloat(pixelsPerDay * 0.3)) }
        else { return max(CGFloat(event.durationDays) * pixelsPerDay, instantaneousEventWidth * 1.5) }
    }
}

// MARK: - Nested TimeAxisView
struct TimeAxisView: View {
    let startDate: Date; let endDate: Date; let totalWidth: CGFloat; let offsetX: CGFloat; let pixelsPerDay: CGFloat
    private var calendar = Calendar.current
    init(startDate: Date, endDate: Date, totalWidth: CGFloat, offsetX: CGFloat, pixelsPerDay: CGFloat) { self.startDate = startDate; self.endDate = endDate; self.totalWidth = totalWidth; self.offsetX = offsetX; self.pixelsPerDay = pixelsPerDay }
    private var totalDays: Int { max(0, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) }
    var body: some View {
        GeometryReader { g in Path { p in p.move(to: CGPoint(x:offsetX,y:g.size.height/2)); p.addLine(to:CGPoint(x:offsetX+totalWidth,y:g.size.height/2)); if totalDays >= 0 { for dO in 0...totalDays { let xP=offsetX+CGFloat(dO)*pixelsPerDay; if xP >= offsetX-(pixelsPerDay/2) && xP <= offsetX+totalWidth+(pixelsPerDay/2) { let dFT=calendar.date(byAdding:.day,value:dO,to:startDate)!; let iSOW=calendar.component(.weekday,from:dFT)==calendar.firstWeekday; let tH:CGFloat=iSOW ? 7:3.5; p.move(to:CGPoint(x:xP,y:g.size.height/2-tH/2)); p.addLine(to:CGPoint(x:xP,y:g.size.height/2+tH/2)) } } } }.stroke(Color.gray.opacity(0.6),lineWidth:0.7); ForEach(0...totalDays,id:\.self) { dO in viewForDateLabel(dayOffset:dO,geometry:g) } }
    }
    @ViewBuilder private func viewForDateLabel(dayOffset dO:Int,geometry g:GeometryProxy) -> some View {
        if pixelsPerDay > 0, let dFL=calendar.date(byAdding:.day,value:dO,to:startDate) {
            let xP=offsetX+CGFloat(dO)*pixelsPerDay; let(fmt,isSig)=getAppropriateFormatter(for:dFL,pixelsPerDay:pixelsPerDay,dayOffset:dO,startDate:startDate)
            let iFM=calendar.component(.day,from:dFL)==1; let iSW=calendar.component(.weekday,from:dFL)==calendar.firstWeekday; let iFWD=calendar.component(.day,from:dFL) <= 7
            if pixelsPerDay >= 65 { labelContentOrEmpty(f:fmt,d:dFL,x:xP,g:g,iS:isSig) }
            else if pixelsPerDay >= 35 { if iSW || iFM { labelContentOrEmpty(f:fmt,d:dFL,x:xP,g:g,iS:isSig) } else {EmptyView()} }
            else if pixelsPerDay >= 15 { if (iSW && iFWD) || iFM { labelContentOrEmpty(f:fmt,d:dFL,x:xP,g:g,iS:isSig) } else {EmptyView()} }
            else { if iFM { labelContentOrEmpty(f:fmt,d:dFL,x:xP,g:g,iS:isSig) } else {EmptyView()} }
        } else {EmptyView()}
    }
    @ViewBuilder private func labelContentOrEmpty(f fmt:DateFormatter,d dFL:Date,x xP:CGFloat,g geo:GeometryProxy,iS isSig:Bool)->some View {
        let apW:CGFloat=pixelsPerDay > 35 ? 40:25; if xP+apW/2 >= offsetX && xP-apW/2 <= offsetX+totalWidth { Text(fmt.string(from:dFL)).font(isSig ? .system(size:9,weight:.medium):.system(size:8)).foregroundColor(Color.secondary).lineLimit(1).fixedSize().position(x:xP,y:geo.size.height/2+(isSig ? 13:11)).padding(.horizontal,1) } else {EmptyView()}
    }
    private func getAppropriateFormatter(for d:Date,pixelsPerDay pPD:CGFloat,dayOffset dO:Int,startDate sD:Date)->(DateFormatter,Bool) {
        let fmt=DateFormatter();var iS=false; if pPD >= 65 {fmt.dateFormat="EEE d";if calendar.component(.weekday,from:d)==calendar.firstWeekday||calendar.component(.day,from:d)==1 {iS=true}} else if pPD >= 35 {fmt.dateFormat="MMM d";if calendar.component(.day,from:d)==1 {iS=true}} else if pPD >= 15 {if calendar.component(.day,from:d)==1||(dO==0&&calendar.isDate(d,inSameDayAs:sD)){fmt.dateFormat="MMM";iS=true}else{fmt.dateFormat="d"}} else{fmt.dateFormat="MMM";iS=true}; return(fmt,iS)
    }
}

// String extension for nilIfEmpty
extension String {
    func nilIfEmpty() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
