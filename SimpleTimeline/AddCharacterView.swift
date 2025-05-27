import SwiftUI
import CoreData

struct AddCharacterView: View {
    // 1. The project we're adding an event to
    @ObservedObject var project: ProjectItem

    // 2. Core Data context
    @Environment(\.managedObjectContext) private var viewContext

    // 3. Dismiss action for the sheet
    @Environment(\.dismiss) var dismiss

    // 4. State variables for the new event's details
    @State private var characterName: String = ""
    @State private var characterDescription: String = ""
    
    // Predefined color options
    private let colorOptions: [String: Color] = [
        "Red": .red, "Green": .green, "Blue": .blue,
        "Orange": .orange, "Purple": .purple, "Yellow": .yellow,
        "Pink": .pink, "Teal": .teal, "Gray": .gray, "Black": .black // Added Black
    ]
    @State private var selectedColorName: String = "Gray" // Default selection

    // Initializer to set up the FetchRequest for characters based on the project
    // (No FetchRequest needed in AddCharacterView itself, that was for AddEventView)
    init(project: ProjectItem) {
        _project = ObservedObject(initialValue: project)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Character Details").font(.headline)) {
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
            .navigationTitle("Add New Character to \(project.title ?? "Project")")
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
                print("Saving character \(newCharacter.name ?? "") with hex: \(newCharacter.colorHex ?? "NIL from save")") // Debug
            } else {
                newCharacter.colorHex = colorToHex(.gray) // Default if something goes wrong
                print("Saving character \(newCharacter.name ?? "") with DEFAULT hex: \(newCharacter.colorHex ?? "NIL from save")") // Debug
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

    // Improved helper function to convert SwiftUI Color to Hex String for macOS
    private func colorToHex(_ color: Color) -> String? {
        let nsColor: NSColor
        // SwiftUI.Color's .cgColor can be nil for some system colors or dynamic colors.
        // It's often more reliable to initialize NSColor(color) on macOS 11+.
        if #available(macOS 11.0, *) {
            nsColor = NSColor(color)
        } else {
            // Fallback for older versions if necessary, though your project target might be macOS 11+
            guard let cgColor = color.cgColor else {
                print("colorToHex: cgColor is nil for \(color)")
                return nil
            }
            nsColor = NSColor(cgColor: cgColor)!
        }

        // Convert to a color space that guarantees RGB components, like sRGB.
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            print("colorToHex: Failed to convert NSColor to sRGB color space for \(nsColor)")
            return nil
        }

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        // We don't need alpha for #RRGGBB format
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        let hexString = String(format: "#%02X%02X%02X", Int(r * 255.0), Int(g * 255.0), Int(b * 255.0))
        // print("colorToHex: Converted \(color) to \(hexString)") // Optional: for deeper debugging
        return hexString
    }
}

struct AddCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Preview Project"
        sampleProject.id = UUID()
        sampleProject.creationDate = Date()

        return AddCharacterView(project: sampleProject)
            .environment(\.managedObjectContext, context)
    }
}
