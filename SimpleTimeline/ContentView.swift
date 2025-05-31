// ContentView.swift

import SwiftUI
import CoreData

// Ensure NotificationNames.swift with .navigateToInternalItem is in your project
// extension Notification.Name {
//     static let navigateToInternalItem = Notification.Name("navigateToInternalItem")
//     static let deselectTimelineItems = Notification.Name("deselectTimelineItems") // Assuming this exists
// }

enum MainViewSelection {
    case projectHome, characters, wiki, timeline
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProjectItem.creationDate, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<ProjectItem>
    
    @State private var activeProject: ProjectItem?
    @State private var selection: MainViewSelection = .projectHome
    @State private var showingSettings = false

    // --- NEW: State for programmatic navigation via internal links ---
    @State private var navigateToWikiPageID: UUID?
    @State private var navigateToCharacterID: UUID?
    // Add navigateToEventID later if needed for linking to events
    // -------------------------------------------------------------

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 16) {
                Group {
                    Button(action: { selection = .projectHome }) {
                        sidebarButtonContent(title: "Project", systemImage: "doc.text.image", isSelected: selection == .projectHome)
                    }
                    .buttonStyle(.plain)

                    Button(action: { selection = .characters }) {
                        sidebarButtonContent(title: "Characters", systemImage: "person.3", isSelected: selection == .characters)
                    }
                    .buttonStyle(.plain)

                    Button(action: { selection = .wiki }) {
                        sidebarButtonContent(title: "Wiki", systemImage: "book.closed", isSelected: selection == .wiki)
                    }
                    .buttonStyle(.plain)

                    Button(action: { selection = .timeline }) {
                        sidebarButtonContent(title: "Timeline", systemImage: "chart.bar.xaxis", isSelected: selection == .timeline)
                    }
                    .buttonStyle(.plain)
                }
                .disabled(activeProject == nil)
                .opacity(activeProject == nil ? 0.4 : 1.0)
                
                Spacer()
                
                Button(action: { activeProject = nil }) {
                    sidebarButtonContent(title: "Home", systemImage: "house", isSelected: activeProject == nil)
                }
                .buttonStyle(.plain)
                
                Button(action: { showingSettings = true }) {
                    sidebarButtonContent(title: "Settings", systemImage: "gearshape", isSelected: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
            
        } detail: {
            ZStack {
                // This background layer is for the global deselect tap
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // This notification is for deselecting items in TimelineView or other detail views
                        NotificationCenter.default.post(name: .deselectTimelineItems, object: nil)
                    }

                // The content sits on top.
                if let project = activeProject {
                    switch selection {
                    case .projectHome:
                        ProjectHomeView(project: project)
                    case .characters:
                        // Pass the binding for programmatic navigation
                        CharacterListView(project: project,
                                          selection: $selection,
                                          itemIDToSelectOnAppear: $navigateToCharacterID)
                    case .wiki:
                        // Pass the binding for programmatic navigation
                        WikiView(project: project,
                                 selection: $selection,
                                 itemIDToSelectOnAppear: $navigateToWikiPageID)
                    case .timeline:
                        TimelineView(project: project, selection: $selection)
                    }
                } else {
                    ProjectSelectionView(
                        projects: projects,
                        activeProject: $activeProject,
                        addProjectAction: addProject
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(80)
        .sheet(isPresented: $showingSettings) {
            VStack {
                Text("Settings").font(.largeTitle).padding()
                Spacer()
                Button("Done") { showingSettings = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
        // --- NEW: Listen for internal navigation requests ---
        .onReceive(NotificationCenter.default.publisher(for: .navigateToInternalItem)) { notification in
            guard let userInfo = notification.userInfo,
                  let urlString = userInfo["urlString"] as? String,
                  let url = URL(string: urlString) else {
                print("ContentView: Received navigateToInternalItem notification with invalid or missing userInfo.")
                return
            }
            handleInternalNavigation(url: url)
        }
        // --------------------------------------------------
    }
    
    @ViewBuilder
    private func sidebarButtonContent(title: String, systemImage: String, isSelected: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolVariant(isSelected ? .fill : .none)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1))
                )

            Text(title)
                .font(.caption)
        }
        .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.7))
        .frame(width: 70, height: 70)
        .contentShape(Rectangle())
    }

    private func addProject() {
        withAnimation {
            let newProject = ProjectItem(context: viewContext)
            newProject.id = UUID()
            newProject.creationDate = Date()
            newProject.title = "New Project \(projects.count + 1)"
            
            activeProject = newProject
            selection = .projectHome
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // --- NEW: Method to handle internal link navigation ---
    private func handleInternalNavigation(url: URL) {
        guard url.scheme == "simpletl", let host = url.host else {
            print("ContentView: Invalid internal URL scheme or host: \(url.absoluteString)")
            return
        }
        
        let itemIDString = url.lastPathComponent
        guard let itemUUID = UUID(uuidString: itemIDString) else {
            print("ContentView: Could not parse UUID from internal URL: \(url.absoluteString)")
            return
        }

        // Ensure a project is active; internal links are project-specific.
        guard activeProject != nil else {
            print("ContentView: Cannot navigate internally, no active project.")
            // Potentially, you could try to find the project that contains this item if your
            // data model allowed items to exist without an active project context, but that adds complexity.
            return
        }

        // Reset navigation states before setting a new one to avoid conflicts
        // if selection doesn't change but target ID does.
        navigateToWikiPageID = nil
        navigateToCharacterID = nil
        // navigateToEventID = nil // For future

        switch host {
        case "wikipage":
            print("ContentView: Navigating to Wiki Page ID: \(itemUUID)")
            selection = .wiki // Switch to the Wiki tab
            navigateToWikiPageID = itemUUID // Tell WikiView which page to select
        case "character":
            print("ContentView: Navigating to Character ID: \(itemUUID)")
            selection = .characters // Switch to the Characters tab
            navigateToCharacterID = itemUUID // Tell CharacterListView which character to select
        // Add "event" case here for future Event linking
        default:
            print("ContentView: Unknown internal link host: \(host) in URL: \(url.absoluteString)")
        }
    }
    // -----------------------------------------------------
}
