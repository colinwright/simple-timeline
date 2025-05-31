// ContentView.swift

import SwiftUI
import CoreData

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
            // UPDATED: The ZStack now has a frame modifier to ensure it fills the entire space.
            ZStack {
                // This background layer is now guaranteed to be the size of the window's detail area.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .deselectTimelineItems, object: nil)
                    }

                // The content sits on top.
                if let project = activeProject {
                    switch selection {
                    case .projectHome:
                        ProjectHomeView(project: project)
                    case .characters:
                        CharacterListView(project: project, selection: $selection)
                    case .wiki:
                        WikiView(project: project, selection: $selection)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity) // This is the critical missing piece.
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
}
