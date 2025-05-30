import SwiftUI
import CoreData

struct ProjectSelectionView: View {
    // Fetched results passed from the main content view
    var projects: FetchedResults<ProjectItem>
    
    // Binding to update the active project in the parent view
    @Binding var activeProject: ProjectItem?
    
    // Action to create a new project, passed from the parent view
    var addProjectAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Welcome to Simple Timeline!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("How to use the app:")
                    .font(.title2)
                    .padding(.bottom, 5)
                Text("• **Characters:** Create and manage the characters in your story.")
                Text("• **Wiki:** Build your world with interconnected pages for lore, locations, and magic systems.")
                Text("• **Timeline:** Visually plot your story's events and character arcs.")
                Text("• **Projects:** Use the buttons below to select a project or create a new one to begin.")
            }
            .frame(maxWidth: 500)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.bottom)

            Divider()

            if projects.isEmpty {
                Text("You don't have any projects yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack {
                    Text("Select a Project")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(projects) { project in
                                Button(action: {
                                    // When a project is clicked, set it as the active one
                                    activeProject = project
                                }) {
                                    Text(project.title ?? "Untitled Project")
                                        .font(.title3)
                                        .padding()
                                        .frame(maxWidth: 300)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.top)
            }
            
            Button(action: addProjectAction) {
                Label("Create New Project", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
            .keyboardShortcut("n", modifiers: .command)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
