import SwiftUI
import CoreData

struct AddCharacterView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var characterName: String = ""
    @State private var characterDescription: String = ""
    
    // Predefined color options (ensure this matches EditCharacterView if shared)
    private let colorOptions: [String: Color] = [
        "Red": .red, "Orange": .orange, "Yellow": .yellow,
        "Green": .green, "Teal": .teal, "Blue": .blue,
        "Purple": .purple, "Pink": .pink, "Gray": .gray, "Black": .black
    ]
    @State private var selectedColorName: String = "Gray" // Default selection

    // Helper to get hex from Color (should be in a shared extension ideally)
    private func colorToHex(_ color: Color) -> String? {
        // Using the static version from EditCharacterView for consistency
        return EditCharacterView.colorToHex(color)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Character Details")) {
                    TextField("Character Name", text: $characterName, prompt: Text("Enter character name"))
                    
                    Picker("Timeline Color", selection: $selectedColorName) {
                        ForEach(colorOptions.keys.sorted(), id: \.self) { colorName in
                            HStack {
                                Text(colorName)
                                Spacer()
                                Circle()
                                    .fill(colorOptions[colorName] ?? .black)
                                    .frame(width: 20, height: 20)
                            }
                            .tag(colorName)
                        }
                    }
                }

                Section(header: Text("Description (Optional)")) {
                    TextEditor(text: $characterDescription)
                        .frame(minHeight: 100, idealHeight: 150, maxHeight: 300)
                        .border(Color.gray.opacity(0.2))
                        .lineSpacing(5)
                }
            }
            .padding()
            .frame(minWidth: 400, idealWidth: 500, minHeight: 350, idealHeight: 450)
            .navigationTitle("Add New Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Character") {
                        saveCharacter()
                        dismiss()
                    }
                    .disabled(characterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCharacter() {
        withAnimation {
            let newCharacter = CharacterItem(context: viewContext)
            newCharacter.id = UUID()
            newCharacter.name = characterName.trimmingCharacters(in: .whitespacesAndNewlines)
            newCharacter.characterDescription = characterDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            newCharacter.creationDate = Date()
            
            if let selectedSwiftUIColor = colorOptions[selectedColorName] {
                newCharacter.colorHex = colorToHex(selectedSwiftUIColor)
            } else {
                newCharacter.colorHex = colorToHex(.gray) // Default
            }
            
            newCharacter.project = project

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving new character: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project"
        
        return AddCharacterView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
