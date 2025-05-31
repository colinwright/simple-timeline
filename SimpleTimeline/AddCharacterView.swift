// AddCharacterView.swift

import SwiftUI
import CoreData

struct AddCharacterView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var characterName: String = ""
    @State private var characterDescription: String = "" // Initial description as plain text
    
    // Re-using color options and helper from EditCharacterView (or make it global)
    private let colorOptions: [String: Color] = [
        "Red": .red, "Orange": .orange, "Yellow": .yellow,
        "Green": .green, "Teal": .teal, "Blue": .blue,
        "Purple": .purple, "Pink": .pink, "Gray": .gray, "Black": .black
    ]
    @State private var selectedColorName: String = "Gray"

    // Helper to convert SwiftUI Color to Hex String (ensure this is accessible, e.g., from Color+Extensions.swift)
    private func colorToHex(_ color: Color) -> String? {
        let nsColor = NSColor(color)
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
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
                    TextEditor(text: $characterDescription) // Input plain text
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
                    Button("Cancel") { dismiss() }
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
            
            // Convert plain text description to RTF Data
            let plainTextAttributedString = NSAttributedString(string: characterDescription)
            do {
                let rtfData = try plainTextAttributedString.data(
                    from: .init(location: 0, length: plainTextAttributedString.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                newCharacter.descriptionRTFData = rtfData
            } catch {
                print("Error converting character description to RTF: \(error)")
                // newCharacter.descriptionRTFData will be nil
            }
            
            newCharacter.creationDate = Date() // Assuming non-optional
            
            if let selectedSwiftUIColor = colorOptions[selectedColorName] {
                newCharacter.colorHex = colorToHex(selectedSwiftUIColor)
            } else {
                newCharacter.colorHex = colorToHex(.gray) // Default if something goes wrong
            }
            
            newCharacter.project = project

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                // Consider more robust error handling
                print("Unresolved error saving new character: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// Ensure EditCharacterView.colorToHex is accessible or duplicate the helper
// For simplicity, I've duplicated it above. Ideally, it's in a Color extension.
