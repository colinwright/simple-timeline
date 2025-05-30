import SwiftUI
import CoreData

// Enum to manage which main view is selected
enum MainViewSelection {
    case characters, wiki, timeline // Changed from .bible to .wiki
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch all projects. We'll use the first one for now.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProjectItem.creationDate, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<ProjectItem>
    
    // State to track the main view selection
    @State private var selection: MainViewSelection = .timeline // Default selection
    
    // State for the settings sheet
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            // Sidebar with navigation icons
            VStack {
                Button(action: { selection = .characters }) {
                    Label("Characters", systemImage: "person.3")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: selection == .characters))

                Button(action: { selection = .wiki }) { // Changed to .wiki
                    Label("Wiki", systemImage: "book.closed") // Changed label text
                }
                .buttonStyle(SidebarButtonStyle(isSelected: selection == .wiki))

                Button(action: { selection = .timeline }) {
                    Label("Timeline", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: selection == .timeline))
                
                Spacer()
                
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(SidebarButtonStyle(isSelected: false))
            }
            .padding(.horizontal, 8)
            .padding(.vertical)
            .frame(minWidth: 50)
            
        } detail: {
            if let project = projects.first {
                switch selection {
                case .characters:
                    CharacterListView(project: project)
                case .wiki: // Changed from .bible to .wiki
                    WikiView() // Use the new WikiView
                case .timeline:
                    TimelineView(project: project)
                }
            } else {
                VStack {
                    Text("Welcome to Simple Timeline!")
                        .font(.largeTitle)
                    Text("Create a project to get started.")
                        .foregroundColor(.secondary)
                    Button("Create New Project", action: addProject)
                        .padding(.top)
                }
            }
        }
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
    
    struct SidebarButtonStyle: ButtonStyle {
        let isSelected: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .labelStyle(.iconOnly)
                .font(.title2)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .cornerRadius(6)
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        }
    }

    private func addProject() {
        withAnimation {
            let newProject = ProjectItem(context: viewContext)
            newProject.id = UUID()
            newProject.creationDate = Date()
            newProject.title = "New Project \(projects.count + 1)" // Ensure unique default names
            
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
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
