// EditCharacterView.swift

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct EditCharacterView: View {
    @ObservedObject var character: CharacterItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.undoManager) var undoManager

    // General State
    @State private var editableName: String
    
    // Color Picker State
    private let colorOptions: [String: Color] = [
        "Red": .red, "Orange": .orange, "Yellow": .yellow,
        "Green": .green, "Teal": .teal, "Blue": .blue,
        "Purple": .purple, "Pink": .pink, "Gray": .gray, "Black": .black
    ]
    @State private var selectedColorName: String

    // Editing State
    @State private var isEditingCharacter: Bool = false

    // Rich Text Description State
    @StateObject private var descriptionActionProxy = RichTextActionProxy()
    
    // Image State
    @State private var showingImageImporter = false
    
    // Link Editing State
    @State private var showingLinkEditorSheet = false
    @State private var linkEditorTitle: String = ""
    @State private var linkEditorURL: String = ""
    @State private var editingLinkContext: EditingLinkContext?

    enum EditingLinkContext {
        case descriptionLink
        case sidebarLink(RelatedLinkItem?)
    }
    
    // Computed Properties for data
    private var characterAttributes: [CharacterAttributeItem] {
        let unsortedAttributes = character.attributes as? Set<CharacterAttributeItem> ?? []
        return unsortedAttributes.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return ($0.name ?? "") < ($1.name ?? "")
        }
    }
    
    private var characterImages: [CharacterImageItem] {
        let unsortedImages = character.images as? Set<CharacterImageItem> ?? []
        return unsortedImages.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    private var characterRelatedLinks: [RelatedLinkItem] {
        let unsortedLinks = character.relatedLinks as? Set<RelatedLinkItem> ?? []
        return unsortedLinks.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    // Color Helper Functions
    static func colorToHex(_ color: Color) -> String? {
        let nsColor = NSColor(color)
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func hexToColorName(_ hex: String?) -> String {
        guard let hex = hex else { return "Gray" }
        for (name, colorValue) in colorOptions {
            if EditCharacterView.colorToHex(colorValue) == hex { return name }
        }
        return "Gray"
    }

    init(character: CharacterItem) {
        self.character = character
        _editableName = State(initialValue: character.name ?? "")
        
        let initialColorNameResolved: String
        if let hex = character.colorHex {
            var foundColorName = "Gray"
            for (name, colorValue) in colorOptions {
                if EditCharacterView.colorToHex(colorValue) == hex {
                    foundColorName = name; break
                }
            }
            initialColorNameResolved = foundColorName
        } else {
            initialColorNameResolved = "Gray"
        }
        _selectedColorName = State(initialValue: initialColorNameResolved)
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(.caption).foregroundColor(.gray).padding(.bottom, -2)
    }

    // MARK: - Body and Sub-views
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            wysiwygToolbar
            contentSplitView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: character) { oldChar, newChar in
            if oldChar.id != newChar.id {
                editableName = newChar.name ?? ""
                selectedColorName = hexToColorName(newChar.colorHex)
                // The proxy doesn't hold data, so no need to update it here.
                // The RichTextEditorView will update itself from its binding.
            } else if !isEditingCharacter {
                 editableName = newChar.name ?? ""
                 selectedColorName = hexToColorName(newChar.colorHex)
            }
        }
        .sheet(isPresented: $showingLinkEditorSheet) {
            if let project = character.project {
                LinkEditorSheetView(
                    linkTitle: $linkEditorTitle,
                    linkUrlString: $linkEditorURL,
                    project: project,
                    isEditingExistingLink: {
                        if case .sidebarLink(let item) = editingLinkContext { return item != nil }
                        return false
                    }(),
                    onSave: { title, urlString in
                        guard let context = editingLinkContext else { return }
                        switch context {
                        case .descriptionLink:
                            descriptionActionProxy.addLink(urlString: urlString)
                        case .sidebarLink(let existingLink):
                            if let linkToUpdate = existingLink {
                                updateRelatedLink(linkToUpdate, title: title, urlString: urlString)
                            } else {
                                addRelatedLink(title: title, urlString: urlString)
                            }
                        }
                    }
                )
            } else {
                 VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                    Text("Cannot Add/Edit Link").font(.headline)
                    Text("This character is not currently associated with a project.").font(.callout).multilineTextAlignment(.center).padding(.horizontal)
                    Button("OK") { showingLinkEditorSheet = false }.padding(.top)
                }.padding().frame(minWidth: 300, idealWidth: 400, minHeight: 200)
            }
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do { let imageData = try Data(contentsOf: url); addCharacterImage(imageData: imageData) }
                    catch { print("Error reading image data: \(error.localizedDescription)") }
                } else { print("Could not access image file.") }
            case .failure(let error): print("Error importing image: \(error.localizedDescription)")
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Spacer()
            if isEditingCharacter {
                Button("Save Character") { saveCharacterChanges(); isEditingCharacter = false }
                .disabled(editableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button("Edit Character") {
                    editableName = character.name ?? ""
                    selectedColorName = hexToColorName(character.colorHex)
                    isEditingCharacter = true
                }
            }
        }
        .padding([.horizontal, .top]).padding(.bottom, 12)
    }

    @ViewBuilder
    private var wysiwygToolbar: some View {
        if isEditingCharacter {
            HStack(spacing: 15) {
                Button(action: { descriptionActionProxy.toggleBold() }) { Image(systemName: "bold") }
                Button(action: { descriptionActionProxy.toggleItalic() }) { Image(systemName: "italic") }
                Button(action: {
                    editingLinkContext = .descriptionLink
                    linkEditorTitle = descriptionActionProxy.getSelectedString() ?? ""
                    linkEditorURL = ""
                    showingLinkEditorSheet = true
                }) { Image(systemName: "link") }
                Spacer()
            }
            .padding(.horizontal).padding(.bottom, 8)
        }
    }

    private var contentSplitView: some View {
        HSplitView {
            leftColumnView
                .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
            rightColumnView
                .frame(width: 320)
        }
    }

    private var leftColumnView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                nameSection
                colorSection
                Divider().padding(.vertical, 5)
                descriptionSection
                Spacer()
            }.padding()
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading) {
            fieldLabel("Name")
            Group {
                if isEditingCharacter {
                    TextField("Character Name", text: $editableName, prompt: Text("Enter character name"))
                } else {
                    Text(character.name ?? "Unnamed Character").textSelection(.enabled)
                }
            }.font(.title2).fontWeight(.bold).textFieldStyle(.plain)
        }
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading) {
            fieldLabel("Timeline Color")
            if isEditingCharacter {
                Picker("Color", selection: $selectedColorName) {
                    ForEach(colorOptions.keys.sorted(), id: \.self) { name in
                        HStack { Text(name); Spacer(); Circle().fill(colorOptions[name]!).frame(width: 16, height: 16) }.tag(name)
                    }
                }.labelsHidden().pickerStyle(.menu)
            } else {
                HStack { Circle().fill(Color(hex: character.colorHex ?? "") ?? .gray).frame(width: 16, height: 16); Text(hexToColorName(character.colorHex)) }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading) {
            fieldLabel("Description")
            if isEditingCharacter {
                RichTextEditorView(
                    rtfData: $character.descriptionRTFData,
                    proxy: descriptionActionProxy,
                    isEditable: true
                )
                .frame(minHeight: 150, idealHeight: 250, maxHeight: 400)
                .border(Color.gray.opacity(0.2))
            } else {
                // Remove the outer ScrollView and apply the frame directly
                // to RichTextEditorView. Its internal NSScrollView will handle scrolling.
                RichTextEditorView(
                    rtfData: .constant(character.descriptionRTFData),
                    proxy: descriptionActionProxy,
                    isEditable: false
                )
                .frame(minHeight: 150, idealHeight: 250, maxHeight: 400) // Apply frame directly
                .padding(.top, 2) // Original padding
                // You might want to add horizontal padding directly here if needed,
                // e.g., .padding(.horizontal, 5)
                // or apply it to the parent VStack of descriptionSection.
                // For now, let's test with just the frame.
            }
        }
    }

    // The rightColumnView and its sub-views do not need any changes.
    // They are included here for completeness of the file.
    private var rightColumnView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Additional Details").font(.title2).fontWeight(.semibold)
                Divider()
                characterImagesSection
                Divider().padding(.vertical, 10)
                customAttributesSection
                Divider().padding(.vertical, 10)
                relatedLinksSection
                Spacer()
            }.padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var characterImagesSection: some View {
        VStack(alignment: .leading) {
            Text("Character Images").font(.headline)
            if characterImages.isEmpty && !isEditingCharacter {
                Text("No images added.").font(.caption).foregroundColor(.gray)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 10) {
                    ForEach(characterImages) { imageItem in
                        VStack {
                            if let imageData = imageItem.imageData, let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5)))
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
                            }
                            if isEditingCharacter {
                                Button(action: { deleteCharacterImage(imageItem) }) {
                                    Image(systemName: "trash.circle.fill").foregroundColor(.red)
                                }.buttonStyle(BorderlessButtonStyle()).padding(.top, 2)
                            }
                        }
                    }
                }
            }
            if isEditingCharacter {
                Button(action: { showingImageImporter = true }) {
                    Label("Add Image", systemImage: "photo.on.rectangle.angled")
                }.padding(.top, 8)
            }
        }
    }

    private var customAttributesSection: some View {
        VStack(alignment: .leading) {
            Text("Custom Attributes").font(.headline)
            if characterAttributes.isEmpty && !isEditingCharacter {
                Text("No custom attributes defined.").font(.caption).foregroundColor(.gray)
            } else {
                ForEach(characterAttributes) { attribute in
                    VStack(alignment: .leading, spacing: 2) {
                        if isEditingCharacter {
                            HStack {
                                TextField("Attribute Name", text: Binding(
                                    get: { attribute.name ?? "" },
                                    set: { newValue in
                                        undoManager?.registerUndo(withTarget: attribute) { t in t.name = attribute.name }
                                        attribute.name = newValue
                                    }), prompt: Text("Name"))
                                .textFieldStyle(PlainTextFieldStyle())
                                Spacer()
                                Button(action: { deleteCharacterAttribute(attribute) }) {
                                    Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                            TextField("Value", text: Binding(
                                get: { attribute.value ?? "" },
                                set: { newValue in
                                    undoManager?.registerUndo(withTarget: attribute) { t in t.value = attribute.value }
                                    attribute.value = newValue
                                }), prompt: Text("Value"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: NSFont.systemFontSize(for: .small)))
                        } else {
                            Text(attribute.name ?? "Unnamed Attribute").fontWeight(.semibold)
                            Text(attribute.value ?? "-").font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                    if attribute != characterAttributes.last || isEditingCharacter { Divider() }
                }
            }
            if isEditingCharacter {
                Button(action: addCharacterAttribute) {
                    Label("Add Attribute", systemImage: "plus.circle.fill")
                }.padding(.top, 8)
            }
        }
    }

    private var relatedLinksSection: some View {
        VStack(alignment: .leading) {
            Text("Related Links").font(.headline)
            if characterRelatedLinks.isEmpty && !isEditingCharacter {
               Text("No related links added.").font(.caption).foregroundColor(.gray)
            } else {
               ForEach(characterRelatedLinks) { linkItem in
                   HStack {
                       VStack(alignment: .leading) {
                           if let urlString = linkItem.urlString {
                               Button(action: {
                                   NotificationCenter.default.post(name: .navigateToInternalItem, object: nil, userInfo: ["urlString": urlString])
                               }) {
                                   Text(linkItem.title ?? urlString).lineLimit(1)
                                       .foregroundColor(URL(string: urlString)?.scheme == "simpletl" ? .accentColor : .blue)
                                       .if(URL(string: urlString)?.scheme == "simpletl" || URL(string: urlString)?.scheme == "http" || URL(string: urlString)?.scheme == "https") { view in
                                           view.underline()
                                       }
                               }
                               .buttonStyle(PlainButtonStyle())
                               if let title = linkItem.title, !title.isEmpty, title != urlString, !(urlString.starts(with: "simpletl://")) {
                                   Text(urlString).font(.caption2).foregroundColor(.gray).lineLimit(1)
                               }
                           } else {
                               Text(linkItem.title ?? "Invalid Link Data").foregroundColor(.red.opacity(0.7))
                           }
                       }
                       Spacer()
                       if isEditingCharacter {
                           Button(action: {
                               editingLinkContext = .sidebarLink(linkItem)
                               linkEditorTitle = linkItem.title ?? ""
                               linkEditorURL = linkItem.urlString ?? ""
                               showingLinkEditorSheet = true
                           }) { Image(systemName: "pencil.circle.fill") }.buttonStyle(BorderlessButtonStyle())
                           Button(action: { deleteRelatedLink(linkItem) }) {
                               Image(systemName: "minus.circle.fill").foregroundColor(.red)
                           }.buttonStyle(BorderlessButtonStyle())
                       }
                   }
                   .padding(.vertical, 2)
                   if linkItem != characterRelatedLinks.last || isEditingCharacter { Divider() }
               }
            }
            if isEditingCharacter {
               Button(action: {
                   editingLinkContext = .sidebarLink(nil)
                   linkEditorTitle = ""
                   linkEditorURL = ""
                   showingLinkEditorSheet = true
               }) { Label("Add Related Link", systemImage: "link.badge.plus") }.padding(.top, 8)
            }
        }
    }
    
    // MARK: - Data Persistence Methods
    private func saveCharacterChanges() {
        let trimmedName = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && character.name != trimmedName { character.name = trimmedName }
        
        let newHex = EditCharacterView.colorToHex(colorOptions[selectedColorName] ?? .gray)
        if character.colorHex != newHex { character.colorHex = newHex }
        
        if viewContext.hasChanges {
            do {
                try viewContext.save(); undoManager?.removeAllActions()
            } catch {
                let nsError = error as NSError; print("Error saving character: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func addCharacterAttribute() {
        withAnimation {
            let newAttr = CharacterAttributeItem(context: viewContext)
            newAttr.id = UUID(); newAttr.name = "New Attribute"; newAttr.value = ""; newAttr.creationDate = Date(); newAttr.displayOrder = Int16(characterAttributes.count)
            character.addToAttributes(newAttr)
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { tc in tc.removeFromAttributes(newAttr); if newAttr.managedObjectContext != nil { viewContext.delete(newAttr) } }
            } catch {
                print("Failed to save context after adding attribute: \(error)")
                character.removeFromAttributes(newAttr); viewContext.delete(newAttr)
            }
        }
    }

    private func deleteCharacterAttribute(_ attribute: CharacterAttributeItem) {
        withAnimation {
            let (n,v,o,d,id) = (attribute.name,attribute.value,attribute.displayOrder,attribute.creationDate,attribute.id)
            character.removeFromAttributes(attribute); viewContext.delete(attribute)
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { tc in
                    let ra = CharacterAttributeItem(context: viewContext); ra.id=id;ra.name=n;ra.value=v;ra.displayOrder=o;ra.creationDate=d; tc.addToAttributes(ra)
                }
            } catch { print("Failed to save context after deleting attribute: \(error)") }
        }
    }

    private func addCharacterImage(imageData: Data) {
        withAnimation {
            let newImageItem = CharacterImageItem(context: viewContext)
            newImageItem.id = UUID(); newImageItem.imageData = imageData; newImageItem.creationDate = Date(); newImageItem.displayOrder = Int16(characterImages.count)
            character.addToImages(newImageItem)
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { tc in tc.removeFromImages(newImageItem); if newImageItem.managedObjectContext != nil { viewContext.delete(newImageItem) } }
            } catch {
                print("Failed to save context after adding image: \(error)")
                character.removeFromImages(newImageItem); viewContext.delete(newImageItem)
            }
        }
    }

    private func deleteCharacterImage(_ imageItem: CharacterImageItem) {
        withAnimation {
            let (id,dat,crd,ord) = (imageItem.id,imageItem.imageData,imageItem.creationDate,imageItem.displayOrder)
            character.removeFromImages(imageItem); viewContext.delete(imageItem)
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { tc in
                    let ri = CharacterImageItem(context: viewContext); ri.id=id;ri.imageData=dat;ri.creationDate=crd;ri.displayOrder=ord; tc.addToImages(ri)
                }
            } catch { print("Failed to save context after deleting image: \(error)") }
        }
    }
    
    private func addRelatedLink(title: String?, urlString: String) {
        withAnimation {
            let newLink = RelatedLinkItem(context: viewContext)
            newLink.id = UUID()
            newLink.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty()
            newLink.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            newLink.creationDate = Date()
            newLink.displayOrder = Int16(characterRelatedLinks.count)
            newLink.character = character
            
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { tc in
                    if newLink.managedObjectContext != nil { viewContext.delete(newLink) }
                }
            } catch {
                print("Failed to save context after adding related link: \(error)")
                if newLink.managedObjectContext != nil { viewContext.delete(newLink) }
            }
        }
    }

    private func updateRelatedLink(_ linkItem: RelatedLinkItem, title: String?, urlString: String) {
        withAnimation {
            let oldTitle = linkItem.title; let oldUrlString = linkItem.urlString
            
            linkItem.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty()
            linkItem.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: linkItem) { tl in
                    tl.title = oldTitle
                    tl.urlString = oldUrlString
                }
            } catch {
                print("Failed to save context after updating related link: \(error)")
                linkItem.title = oldTitle; linkItem.urlString = oldUrlString
            }
        }
    }

    private func deleteRelatedLink(_ linkItem: RelatedLinkItem) {
        withAnimation {
            let linkID = linkItem.id
            let linkTitle = linkItem.title
            let linkUrl = linkItem.urlString
            let linkCreationDate = linkItem.creationDate
            let linkDisplayOrder = linkItem.displayOrder
            
            viewContext.delete(linkItem)
            
            do {
                try viewContext.save()
                undoManager?.registerUndo(withTarget: character) { targetCharacter in
                    let recreatedLink = RelatedLinkItem(context: viewContext)
                    recreatedLink.id = linkID
                    recreatedLink.title = linkTitle
                    recreatedLink.urlString = linkUrl
                    recreatedLink.creationDate = linkCreationDate
                    recreatedLink.displayOrder = linkDisplayOrder
                    recreatedLink.character = targetCharacter
                }
            } catch { print("Failed to save context after deleting related link: \(error)") }
        }
    }
}

// Helper View for conditional modifier
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
