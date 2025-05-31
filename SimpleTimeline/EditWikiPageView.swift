// EditWikiPageView.swift

import SwiftUI
import CoreData
import UniformTypeIdentifiers // Required for .fileImporter

// Assuming ReadOnlyRichTextView is defined in HelperViews.swift or another shared file.

struct EditWikiPageView: View {
    @ObservedObject var page: WikiPageItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.undoManager) var undoManager

    @State private var editableTitle: String
    @State private var isEditingPage: Bool = false
    
    @StateObject private var textEditorCoordinator: RichTextCoordinator

    @State private var showingAddLinkSheet = false
    @State private var linkURLInput: String = ""

    // --- FOR IMAGES ---
    @State private var showingImageImporter = false
    // ----------------------

    private var wikiPageAttributes: [WikiPageAttributeItem] {
        let unsortedAttributes = page.attributes as? Set<WikiPageAttributeItem> ?? []
        return unsortedAttributes.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return ($0.name ?? "") < ($1.name ?? "")
        }
    }

    private var wikiPageImages: [WikiPageImageItem] {
        let unsortedImages = page.images as? Set<WikiPageImageItem> ?? []
        return unsortedImages.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    init(page: WikiPageItem) {
        self.page = page
        _editableTitle = State(initialValue: page.title ?? "")
        
        let coordinatorRtfDataBinding = Binding<Data?>(
            get: { page.contentRTFData },
            set: { newValue in page.contentRTFData = newValue }
        )
        _textEditorCoordinator = StateObject(wrappedValue: RichTextCoordinator(rtfData: coordinatorRtfDataBinding))
    }
    
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(.caption).foregroundColor(.gray).padding(.bottom, -2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar (Edit/Save buttons)
            HStack {
                Spacer()
                if isEditingPage {
                    Button("Save Page") { savePageChanges(); isEditingPage = false }
                    .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Page") {
                        editableTitle = page.title ?? ""
                        textEditorCoordinator.rtfData = page.contentRTFData // Sync coordinator
                        isEditingPage = true
                    }
                }
            }
            .padding([.horizontal, .top]).padding(.bottom, 12)

            // WYSIWYG Toolbar
            if isEditingPage {
                HStack(spacing: 15) {
                    Button(action: { textEditorCoordinator.toggleBold() }) { Image(systemName: "bold") }
                    Button(action: { textEditorCoordinator.toggleItalic() }) { Image(systemName: "italic") }
                    Button(action: { linkURLInput = ""; showingAddLinkSheet = true }) { Image(systemName: "link") }
                    Spacer()
                }
                .padding(.horizontal).padding(.bottom, 8)
            }
            
            HSplitView {
                // --- Left Column (Main Content) ---
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if isEditingPage {
                            TextField("Page Title", text: $editableTitle, prompt: Text("Enter page title"))
                        } else {
                            Text(page.title ?? "Untitled Page").textSelection(.enabled)
                        }
                    }
                    .font(.largeTitle).fontWeight(.bold).textFieldStyle(.plain)
                    .padding([.horizontal, .top]).padding(.bottom, 10)
                    
                    Divider().padding(.horizontal)

                    if isEditingPage {
                        RichTextEditorView(rtfData: $page.contentRTFData, coordinator: textEditorCoordinator)
                            .padding(.top, 5)
                    } else {
                        ScrollView { // Add ScrollView for read-only content too
                            ReadOnlyRichTextView(rtfData: page.contentRTFData).padding()
                        }
                    }
                }
                .frame(minWidth: 350, idealWidth: 700, maxWidth: .infinity)

                // --- Right Column (Sidebar) ---
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Details").font(.title2).fontWeight(.semibold)
                        Divider()

                        // --- Page Images Section (MOVED TO TOP) ---
                        Text("Page Images").font(.headline)
                        if wikiPageImages.isEmpty && !isEditingPage {
                            Text("No images added.").font(.caption).foregroundColor(.gray)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 10) {
                                ForEach(wikiPageImages) { imageItem in
                                    VStack {
                                        if let imageData = imageItem.imageData, let nsImage = NSImage(data: imageData) {
                                            Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
                                                .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 4))
                                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5)))
                                        } else {
                                            Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80)
                                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                        }
                                        if isEditingPage {
                                            Button(action: { deleteWikiPageImage(imageItem) }) {
                                                Image(systemName: "trash.circle.fill").foregroundColor(.red)
                                            }.buttonStyle(BorderlessButtonStyle()).padding(.top, 2)
                                        }
                                    }
                                }
                            }
                        }
                        if isEditingPage {
                            Button(action: { showingImageImporter = true }) {
                                Label("Add Image", systemImage: "photo.on.rectangle.angled")
                            }.padding(.top, 8)
                        }
                        Divider().padding(.vertical, 10)
                        // --- End Page Images Section ---

                        Group { // Existing Metadata
                            fieldLabel("Last Modified")
                            Text((page.lastModifiedDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                            fieldLabel("Created")
                            Text((page.creationDate ?? Date()).formatted(date: .abbreviated, time: .omitted))
                        }.padding(.bottom, 5)
                        Divider()
                        
                        // Custom Attributes Section
                        Text("Attributes").font(.headline)
                        if wikiPageAttributes.isEmpty && !isEditingPage {
                            Text("No attributes defined.").font(.caption).foregroundColor(.gray)
                        } else {
                            ForEach(wikiPageAttributes) { attribute in
                                VStack(alignment: .leading, spacing: 2) {
                                    if isEditingPage {
                                        HStack {
                                            TextField("Attribute Name", text: Binding(
                                                get: { attribute.name ?? "" },
                                                set: { newValue in
                                                    undoManager?.registerUndo(withTarget: attribute) { t in t.name = attribute.name }
                                                    attribute.name = newValue
                                                }), prompt: Text("Name"))
                                            .textFieldStyle(PlainTextFieldStyle())
                                            Spacer()
                                            Button(action: { deleteWikiPageAttribute(attribute) }) {
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
                                if attribute != wikiPageAttributes.last || isEditingPage { Divider() }
                            }
                        }
                        if isEditingPage {
                            Button(action: addWikiPageAttribute) {
                                Label("Add Attribute", systemImage: "plus.circle.fill")
                            }.padding(.top, 8)
                        }
                        Divider().padding(.vertical, 10)

                        Text("Related Links").font(.headline) // Placeholder
                        Text("(Functionality to be implemented)").font(.caption).foregroundColor(.gray)
                        Spacer()
                    }.padding()
                }
                .frame(width: 320)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: page) { oldPage, newPage in
             if oldPage.id != newPage.id { editableTitle = newPage.title ?? "" }
             else if !isEditingPage { editableTitle = newPage.title ?? "" }
        }
        .sheet(isPresented: $showingAddLinkSheet) { /* ... Add Link Sheet from previous version ... */
            VStack(spacing: 15) {
                Text("Add Link").font(.headline).padding(.top)
                Text("Selected text will be linked...").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                TextField("Enter URL...", text: $linkURLInput).textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Button("Cancel") { showingAddLinkSheet = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Apply Link") {
                        if !linkURLInput.isEmpty { textEditorCoordinator.addLink(urlString: linkURLInput) }
                        showingAddLinkSheet = false
                    }.keyboardShortcut(.defaultAction).disabled(linkURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding().frame(minWidth: 350, idealWidth: 450, minHeight: 180)
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do { let imageData = try Data(contentsOf: url); addWikiPageImage(imageData: imageData) }
                    catch { print("Error reading image data: \(error.localizedDescription)") }
                } else { print("Could not access image file.") }
            case .failure(let error): print("Error importing image: \(error.localizedDescription)")
            }
        }
    }

    private func savePageChanges() {
        let trimmedTitle = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasMeaningfulChanges = false
        if !trimmedTitle.isEmpty && page.title != trimmedTitle { page.title = trimmedTitle; hasMeaningfulChanges = true }
        if viewContext.hasChanges { hasMeaningfulChanges = true }
        if hasMeaningfulChanges { page.lastModifiedDate = Date() }
        if viewContext.hasChanges {
            do { try viewContext.save(); undoManager?.removeAllActions() }
            catch { let nsError = error as NSError; print("Error saving wiki page: \(nsError), \(nsError.userInfo)") }
        }
    }

    private func addWikiPageAttribute() { // Renamed from addAttribute
        withAnimation {
            let newAttr = WikiPageAttributeItem(context: viewContext)
            newAttr.id = UUID(); newAttr.name = "New Attribute"; newAttr.value = ""; newAttr.creationDate = Date(); newAttr.displayOrder = Int16(wikiPageAttributes.count)
            page.addToAttributes(newAttr) // Assumes this generated method exists
            do {
                try viewContext.save() // Save immediately
                undoManager?.registerUndo(withTarget: page) { p in
                    p.removeFromAttributes(newAttr)
                    if newAttr.managedObjectContext != nil { viewContext.delete(newAttr) }
                }
            } catch {
                print("Failed to save context after adding wiki attribute: \(error)")
                page.removeFromAttributes(newAttr); viewContext.delete(newAttr) // Rollback
            }
        }
    }

    private func deleteWikiPageAttribute(_ attribute: WikiPageAttributeItem) { // Renamed
        withAnimation {
            let (n,v,o,d,id) = (attribute.name,attribute.value,attribute.displayOrder,attribute.creationDate,attribute.id)
            page.removeFromAttributes(attribute); viewContext.delete(attribute)
            do {
                try viewContext.save() // Save immediately
                undoManager?.registerUndo(withTarget: page) { p in
                    let ra = WikiPageAttributeItem(context: viewContext); ra.id=id;ra.name=n;ra.value=v;ra.displayOrder=o;ra.creationDate=d; p.addToAttributes(ra)
                }
            } catch { print("Failed to save context after deleting wiki attribute: \(error)") }
        }
    }

    private func addWikiPageImage(imageData: Data) {
        withAnimation {
            let newImageItem = WikiPageImageItem(context: viewContext)
            newImageItem.id = UUID(); newImageItem.imageData = imageData; newImageItem.creationDate = Date(); newImageItem.displayOrder = Int16(wikiPageImages.count)
            page.addToImages(newImageItem) // Assumes this generated method exists
            do {
                try viewContext.save() // Save immediately
                undoManager?.registerUndo(withTarget: page) { p in
                    p.removeFromImages(newImageItem)
                    if newImageItem.managedObjectContext != nil { viewContext.delete(newImageItem) }
                }
            } catch {
                print("Failed to save context after adding wiki image: \(error)")
                page.removeFromImages(newImageItem); viewContext.delete(newImageItem) // Rollback
            }
        }
    }

    private func deleteWikiPageImage(_ imageItem: WikiPageImageItem) {
        withAnimation {
            let (id,dat,cap,crd,ord) = (imageItem.id, imageItem.imageData, imageItem.caption, imageItem.creationDate, imageItem.displayOrder)
            page.removeFromImages(imageItem); viewContext.delete(imageItem)
            do {
                try viewContext.save() // Save immediately
                undoManager?.registerUndo(withTarget: page) { p in
                    let ri = WikiPageImageItem(context: viewContext); ri.id=id; ri.imageData=dat; ri.caption=cap; ri.creationDate=crd; ri.displayOrder=ord;
                    p.addToImages(ri)
                }
            } catch { print("Failed to save context after deleting wiki image: \(error)") }
        }
    }
}
