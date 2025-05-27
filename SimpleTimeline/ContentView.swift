import SwiftUI
import CoreData

// Updated Enum for programmatic tab selection
enum ProjectDetailTab {
    case events, characters, arcs, timeline // Reordered
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProjectItem.creationDate, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<ProjectItem>

    // Selected project state
    @State private var selectedProject: ProjectItem?
    
    // Optional: State for programmatic tab selection
    // @State private var selectedDetailTab: ProjectDetailTab = .events

    var body: some View {
        NavigationView {
            // Sidebar List
            List(selection: $selectedProject) {
                ForEach(projects) { project in
                    Text(project.title ?? "Untitled Project")
                        .tag(project)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteProject(project)
                            } label: {
                                Label("Delete Project", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deleteProjectsFromOffsets)
            }
            .listStyle(SidebarListStyle())
            .toolbar {
                ToolbarItem {
                    Button(action: addProject) {
                        Label("Add Project", systemImage: "plus")
                    }
                }
            }
            // Detail View Area
            if let project = selectedProject {
                TabView { // To use programmatic selection: TabView(selection: $selectedDetailTab)
                    EventListView(project: project)
                        .tabItem {
                            Label("Events", systemImage: "list.star")
                        }
                        .tag(ProjectDetailTab.events)

                    CharacterListView(project: project)
                        .tabItem {
                            Label("Characters", systemImage: "person.3.fill")
                        }
                        .tag(ProjectDetailTab.characters)
                    
                    CharacterArcListView(project: project) // Moved Arcs before Timeline
                        .tabItem {
                            Label("Arcs", systemImage: "arrow.triangle.branch")
                        }
                        .tag(ProjectDetailTab.arcs)

                    TimelineView(project: project)
                        .tabItem {
                            Label("Timeline", systemImage: "chart.bar.xaxis")
                        }
                        .tag(ProjectDetailTab.timeline)
                }
            } else {
                Text("Select a project to see its details.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func addProject() {
        withAnimation {
            let newProject = ProjectItem(context: viewContext)
            newProject.id = UUID()
            newProject.creationDate = Date()
            newProject.title = "New Project \(projects.count + 1)"
            
            selectedProject = newProject
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteProjectsFromOffsets(offsets: IndexSet) {
        withAnimation {
            let projectsToDelete = offsets.map { projects[$0] }
            
            if let currentSelection = selectedProject, projectsToDelete.contains(currentSelection) {
                selectedProject = nil
            }
            
            projectsToDelete.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteProject(_ project: ProjectItem) {
        withAnimation {
            if selectedProject == project {
                selectedProject = nil
            }
            viewContext.delete(project)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
