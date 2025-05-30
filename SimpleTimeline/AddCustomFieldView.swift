import SwiftUI
import CoreData

// Enum to define the types of custom fields
enum FieldType: String, CaseIterable, Identifiable {
    case singleLine = "Single Line Text"
    case multiLine = "Multi-line Text"
    
    var id: String { self.rawValue }
}

struct AddCustomFieldView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var fieldName: String = ""
    @State private var selectedFieldType: FieldType = .singleLine

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Custom Field Details")) {
                    TextField("Field Name (e.g., Theme, Logline)", text: $fieldName)
                    
                    Picker("Field Type", selection: $selectedFieldType) {
                        ForEach(FieldType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 400, idealWidth: 450, maxWidth: 600,
                   minHeight: 250, idealHeight: 300, maxHeight: 400)
            .navigationTitle("Add Custom Field")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Field") {
                        saveCustomFieldDefinition()
                        dismiss()
                    }
                    .disabled(fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCustomFieldDefinition() {
        withAnimation {
            let newFieldDefinition = CustomFieldDefinitionItem(context: viewContext)
            newFieldDefinition.id = UUID()
            newFieldDefinition.name = fieldName.trimmingCharacters(in: .whitespacesAndNewlines)
            newFieldDefinition.fieldType = selectedFieldType.rawValue
            newFieldDefinition.value = "" // Initialize with an empty value
            newFieldDefinition.creationDate = Date() // Set creation date
            newFieldDefinition.project = project // Associate with the current project
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error saving new custom field definition: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddCustomFieldView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project for Custom Fields"
        
        return AddCustomFieldView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
