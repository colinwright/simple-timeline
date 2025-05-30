import SwiftUI
import CoreData

struct ProjectHomeView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext

    @State private var projectTitle: String
    @State private var showingAddCustomFieldSheet = false
    @State private var isEditingProjectDetails: Bool = false

    @FetchRequest private var customFieldDefinitions: FetchedResults<CustomFieldDefinitionItem>

    init(project: ProjectItem) {
        self.project = project
        _projectTitle = State(initialValue: project.title ?? "")
        
        _customFieldDefinitions = FetchRequest<CustomFieldDefinitionItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CustomFieldDefinitionItem.creationDate, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default
        )
    }

    // Consistent style for field labels
    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Overview",
                    isProjectTitleClickable: false
                )
            } trailing: {
                if isEditingProjectDetails {
                    Button("Save Details") {
                        saveChanges()
                        isEditingProjectDetails = false
                    }
                    .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Details") {
                        projectTitle = project.title ?? "" // Ensure current title is loaded for editing
                        isEditingProjectDetails = true
                    }
                }
            }

            Form {
                // Project Title Section (no explicit Section header)
                VStack(alignment: .leading) {
                    fieldLabel("Project Title") // Use consistent field label
                    if isEditingProjectDetails {
                        TextField("", text: $projectTitle, prompt: Text("Project Title")) // Prompt for empty state
                    } else {
                        Text(project.title ?? "Untitled Project")
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4) // Add some vertical padding to each field block

                // Custom Fields Section (no explicit Section header)
                // The "Custom Fields" header is removed.
                ForEach(customFieldDefinitions) { field in
                    VStack(alignment: .leading) {
                        fieldLabel(field.name ?? "Unnamed Field") // Use consistent field label
                        
                        if isEditingProjectDetails {
                            if field.fieldType == FieldType.multiLine.rawValue {
                                TextEditor(text: Binding(
                                    get: { field.value ?? "" },
                                    set: { field.value = $0 }
                                ))
                                .frame(minHeight: 50, maxHeight: 100) // Kept adjusted height
                                .overlay( // Using overlay for border to avoid extra padding issues with TextEditor
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            } else { // Single Line
                                TextField("", text: Binding( // No default prompt text for value
                                    get: { field.value ?? "" },
                                    set: { field.value = $0 }
                                ), prompt: Text("Enter value")) // Prompt for empty state
                            }
                        } else {
                            // Read-only display
                            Text(field.value?.isEmpty == false ? (field.value ?? "") : (field.fieldType == FieldType.multiLine.rawValue ? "(No content)" : "-"))
                                .lineLimit(field.fieldType == FieldType.multiLine.rawValue ? nil : 1)
                                .textSelection(.enabled)
                                .foregroundColor(field.value?.isEmpty == false ? .primary : .secondary)
                                .frame(minHeight: field.fieldType == FieldType.multiLine.rawValue && field.value?.isEmpty != false ? 20 : nil, alignment: .leading) // Ensure some height for empty multi-line display
                                .padding(.top, field.fieldType == FieldType.multiLine.rawValue && field.value?.isEmpty != false ? 2 : 0) // Small top padding for multi-line text to align better
                        }
                    }
                    .padding(.vertical, 4) // Add some vertical padding to each field block
                }
                .onDelete(perform: isEditingProjectDetails ? deleteCustomFields : nil)
                
                // "Add Custom Field" button
                if isEditingProjectDetails {
                    Button {
                        showingAddCustomFieldSheet = true
                    } label: {
                        Label("Add New Custom Field", systemImage: "plus.circle.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10) // Space above this button
                }
            }
            .padding([.horizontal, .bottom])
            .frame(maxWidth: 450)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: project) { _, newProject in
            if !isEditingProjectDetails {
                projectTitle = newProject.title ?? ""
            }
        }
        .sheet(isPresented: $showingAddCustomFieldSheet) {
            AddCustomFieldView(project: project)
        }
    }

    private func deleteCustomFields(offsets: IndexSet) {
        withAnimation {
            offsets.map { customFieldDefinitions[$0] }.forEach(viewContext.delete)
        }
    }

    private func saveChanges() {
        let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && project.title != trimmedTitle {
            project.title = trimmedTitle
        }
        
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error saving project details: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ProjectHomeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "My Awesome Novel"

        let customField1 = CustomFieldDefinitionItem(context: context)
        customField1.id = UUID(); customField1.name = "Theme"; customField1.fieldType = FieldType.singleLine.rawValue; customField1.value = "Redemption"; customField1.project = sampleProject; customField1.creationDate = Date()
        
        let customField2 = CustomFieldDefinitionItem(context: context)
        customField2.id = UUID(); customField2.name = "Logline"; customField2.fieldType = FieldType.multiLine.rawValue; customField2.value = "A long description of the story's logline that might wrap multiple lines."; customField2.project = sampleProject; customField2.creationDate = Date(timeIntervalSinceNow: -100)

        let customField3 = CustomFieldDefinitionItem(context: context)
        customField3.id = UUID(); customField3.name = "Empty Multi-line"; customField3.fieldType = FieldType.multiLine.rawValue; customField3.value = ""; customField3.project = sampleProject; customField3.creationDate = Date(timeIntervalSinceNow: -200)


        return NavigationView {
            ProjectHomeView(project: sampleProject)
                .environment(\.managedObjectContext, context)
        }
    }
}
