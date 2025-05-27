import SwiftUI
import CoreData

struct EditCharacterView: View {
    // 1. The character we are editing
    @ObservedObject var character: CharacterItem

    // 2. Core Data context
    @Environment(\.managedObjectContext) private var viewContext

    // 3. Dismiss action for the sheet
    @Environment(\.dismiss) var dismiss

    // 4. State variables, initialized with the character's current details
    @State private var characterName: String
    @State private var characterDescription: String
    @State private var selectedColorName: String

    // Predefined color options (should match AddCharacterView)
    private let colorOptions: [String: Color] = [
        "Red": .red, "Green": .green, "Blue": .blue,
        "Orange": .orange, "Purple": .purple, "Yellow": .yellow,
        "Pink": .pink, "Teal": .teal, "Gray": .gray, "Black": .black
    ]

    // Initializer to load character data into state variables
    init(character: CharacterItem) {
        _character = ObservedObject(initialValue: character)
        _characterName = State(initialValue: character.name ?? "")
        _characterDescription = State(initialValue: character.characterDescription ?? "")
        
        // Find the color name from the hex, or default
        var initialColorName = "Gray" // Default
        if let hex = character.colorHex {
            for (name, color) in colorOptions {
                // Call the static version of colorToHex
                if EditCharacterView.colorToHex(color) == hex {
                    initialColorName = name
                    break
                }
            }
        }
        _selectedColorName = State(initialValue: initialColorName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Character Details").font(.headline)) {
                    TextField("Character Name", text: $characterName)
                    
                    Section(header: Text("Description (Optional)")) {
                        TextEditor(text: $characterDescription)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3), width: 1)
                    }

                    Section(header: Text("Timeline Color")) {
                        Picker("Select Color", selection: $selectedColorName) {
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
                }
            }
            .padding()
            .frame(minWidth: 400, idealWidth: 500, minHeight: 350, idealHeight: 450)
            .navigationTitle("Edit \(character.name ?? "Character")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(characterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        withAnimation {
            character.name = characterName.trimmingCharacters(in: .whitespacesAndNewlines)
            character.characterDescription = characterDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let selectedSwiftUIColor = colorOptions[selectedColorName] {
                // Call the static version of colorToHex
                character.colorHex = EditCharacterView.colorToHex(selectedSwiftUIColor)
                print("Updating character \(character.name ?? "") with hex: \(character.colorHex ?? "NIL from save")") // Debug
            } else {
                character.colorHex = EditCharacterView.colorToHex(.gray) // Default
                print("Updating character \(character.name ?? "") with DEFAULT hex: \(character.colorHex ?? "NIL from save")") // Debug
            }
            // creationDate and id are not changed.
            // project link is already established.

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving character changes: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // Helper function to convert SwiftUI Color to Hex String - now static
    static func colorToHex(_ color: Color) -> String? {
        let nsColor: NSColor
        if #available(macOS 11.0, *) {
            nsColor = NSColor(color)
        } else {
            guard let cgColor = color.cgColor else {
                print("colorToHex (static): cgColor is nil for \(color)")
                return nil
            }
            nsColor = NSColor(cgColor: cgColor)!
        }

        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            print("colorToHex (static): Failed to convert NSColor to sRGB for \(nsColor)")
            return nil
        }

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        let hexString = String(format: "#%02X%02X%02X", Int(r * 255.0), Int(g * 255.0), Int(b * 255.0))
        return hexString
    }
}

struct EditCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context) // Needed for character's project link
        sampleProject.title = "Preview Project"
        
        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Character to Edit"
        sampleCharacter.characterDescription = "An existing description."
        sampleCharacter.colorHex = "#00FF00" // Green
        sampleCharacter.id = UUID()
        sampleCharacter.creationDate = Date()
        sampleCharacter.project = sampleProject


        return EditCharacterView(character: sampleCharacter)
            .environment(\.managedObjectContext, context)
    }
}
