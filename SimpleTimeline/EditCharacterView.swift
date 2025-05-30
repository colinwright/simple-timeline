import SwiftUI
import CoreData

struct EditCharacterView: View {
    @ObservedObject var character: CharacterItem
    @Environment(\.managedObjectContext) private var viewContext

    @State private var editableName: String
    @State private var editableDescription: String
    @State private var selectedColorName: String // For the picker

    @State private var isEditingCharacter: Bool = false

    // Color options
    private let colorOptions: [String: Color] = [
        "Red": .red, "Orange": .orange, "Yellow": .yellow,
        "Green": .green, "Teal": .teal, "Blue": .blue,
        "Purple": .purple, "Pink": .pink, "Gray": .gray, "Black": .black
    ]
    
    // Static helper to convert SwiftUI Color to Hex String
    static func colorToHex(_ color: Color) -> String? {
        let nsColor = NSColor(color)
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func hexToColorName(_ hex: String?) -> String {
        guard let hex = hex else { return "Gray" }
        for (name, color) in colorOptions {
            if EditCharacterView.colorToHex(color) == hex {
                return name
            }
        }
        return "Gray" // Default if hex doesn't match
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.bottom, -2)
    }

    init(character: CharacterItem) {
        self.character = character
        _editableName = State(initialValue: character.name ?? "")
        _editableDescription = State(initialValue: character.characterDescription ?? "")
        // Initialize selectedColorName by finding the name for the character's current hex
        var initialColorName = "Gray" // Default
        if let hex = character.colorHex {
            for (name, colorValue) in colorOptions {
                if EditCharacterView.colorToHex(colorValue) == hex {
                    initialColorName = name
                    break
                }
            }
        }
        _selectedColorName = State(initialValue: initialColorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if isEditingCharacter {
                    Button("Save Character") {
                        saveCharacterChanges()
                        isEditingCharacter = false
                    }
                    .disabled(editableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Character") {
                        editableName = character.name ?? ""
                        editableDescription = character.characterDescription ?? ""
                        selectedColorName = hexToColorName(character.colorHex)
                        isEditingCharacter = true
                    }
                }
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Character Name
                    VStack(alignment: .leading) {
                        fieldLabel("Name")
                        if isEditingCharacter {
                            TextField("", text: $editableName, prompt: Text("Character name"))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text(character.name ?? "Unnamed Character")
                                .font(.title2)
                                .fontWeight(.bold)
                                .textSelection(.enabled)
                        }
                    }

                    // Character Color
                    VStack(alignment: .leading) {
                        fieldLabel("Timeline Color")
                        if isEditingCharacter {
                            Picker("Color", selection: $selectedColorName) {
                                ForEach(colorOptions.keys.sorted(), id: \.self) { name in
                                    HStack {
                                        Text(name)
                                        Spacer()
                                        Circle().fill(colorOptions[name]!).frame(width: 16, height: 16)
                                    }
                                    .tag(name)
                                }
                            }
                            .labelsHidden()
                        } else {
                            HStack {
                                Circle()
                                    .fill(Color(hex: character.colorHex ?? "") ?? .gray)
                                    .frame(width: 16, height: 16)
                                Text(hexToColorName(character.colorHex))
                            }
                        }
                    }
                    
                    // Character Description
                    VStack(alignment: .leading) {
                        fieldLabel("Description")
                        if isEditingCharacter {
                            TextEditor(text: $editableDescription)
                                .frame(minHeight: 100, idealHeight: 200, maxHeight: .infinity)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .font(.body)
                        } else {
                            Text(character.characterDescription?.isEmpty == false ? (character.characterDescription ?? "") : "(No description)")
                                .textSelection(.enabled)
                                .foregroundColor(character.characterDescription?.isEmpty == false ? .primary : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: character) { _, newCharacter in // Use new signature for onChange
            if !isEditingCharacter {
                editableName = newCharacter.name ?? ""
                editableDescription = newCharacter.characterDescription ?? ""
                selectedColorName = hexToColorName(newCharacter.colorHex)
            }
        }
    }

    private func saveCharacterChanges() {
        let trimmedName = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        // No need for a separate 'hasChanges' boolean, viewContext.hasChanges handles it.

        if !trimmedName.isEmpty && character.name != trimmedName {
            character.name = trimmedName
        }
        if character.characterDescription != editableDescription {
            character.characterDescription = editableDescription
        }
        
        let newHex = EditCharacterView.colorToHex(colorOptions[selectedColorName] ?? .gray)
        if character.colorHex != newHex {
            character.colorHex = newHex
        }

        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error saving character: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct EditCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Test Project"

        let sampleCharacter = CharacterItem(context: context)
        sampleCharacter.name = "Hero Preview"
        sampleCharacter.characterDescription = "A brave hero for preview purposes."
        sampleCharacter.colorHex = EditCharacterView.colorToHex(.blue)
        sampleCharacter.project = sampleProject
        
        return EditCharacterView(character: sampleCharacter)
            .environment(\.managedObjectContext, context)
            .frame(width: 400, height: 600)
    }
}
