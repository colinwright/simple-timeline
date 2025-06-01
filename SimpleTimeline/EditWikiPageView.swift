// EditWikiPageView.swift

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct EditWikiPageView: View {
    @ObservedObject var page: WikiPageItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.undoManager) var undoManager

    @State private var editableTitle: String
    @State private var isEditingPage: Bool = false
    
    @StateObject private var textEditorActionProxy = RichTextActionProxy()

    // Link Editor Sheet State
    @State private var showingLinkEditorSheet = false
    @State private var linkEditorTitle: String = ""
    @State private var linkEditorURL: String = ""
    
    enum LinkEditingContext {
        case mainDescription
        case sidebarLink(RelatedLinkItem?)
    }
    @State private var currentLinkEditingContext: LinkEditingContext?
    
    @State private var showingImageImporter = false

    private var sortedRelatedLinks: [RelatedLinkItem] {
        let unsortedLinks = page.relatedLinks as? Set<RelatedLinkItem> ?? []
        return unsortedLinks.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

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
    }
    
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(.caption).foregroundColor(.gray).padding(.bottom, -2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { // Header Bar
                Spacer()
                if isEditingPage {
                    Button("Save Page") { savePageChanges(); isEditingPage = false }
                    .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Page") {
                        editableTitle = page.title ?? ""
                        isEditingPage = true
                    }
                }
            }
            .padding([.horizontal, .top]).padding(.bottom, 12)

            if isEditingPage { // WYSIWYG Toolbar
                HStack(spacing: 15) {
                    Button(action: { textEditorActionProxy.toggleBold() }) { Image(systemName: "bold") }
                    Button(action: { textEditorActionProxy.toggleItalic() }) { Image(systemName: "italic") }
                    Button(action: {
                        currentLinkEditingContext = .mainDescription
                        linkEditorTitle = textEditorActionProxy.getSelectedString() ?? ""
                        linkEditorURL = ""
                        showingLinkEditorSheet = true
                    }) { Image(systemName: "link") }
                    Spacer()
                }
                .padding(.horizontal).padding(.bottom, 8)
            }
            
            HSplitView {
                            VStack(alignment: .leading, spacing: 0) { // Left Column (Main Content)
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
                                    RichTextEditorView(
                                        rtfData: $page.contentRTFData,
                                        proxy: textEditorActionProxy,
                                        isEditable: true
                                    )
                                    // Allow the editable view to expand fully
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 5)
                                } else {
                                    // Read-only branch:
                                    // REMOVE the outer SwiftUI ScrollView.
                                    // Apply flexible frame directly to RichTextEditorView.
                                    // Its internal NSScrollView will handle scrolling.
                                    RichTextEditorView(
                                        rtfData: .constant(page.contentRTFData),
                                        proxy: textEditorActionProxy,
                                        isEditable: false
                                    )
                                    .padding() // Padding for the text content itself
                                    // Tell RichTextEditorView to take up all available space.
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            // This frame on the parent VStack is crucial for HSplitView
                            .frame(minWidth: 350, idealWidth: 700, maxWidth: .infinity) 

                ScrollView { // Right Column (Sidebar)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Details").font(.title2).fontWeight(.semibold)
                        Divider()
                        pageImagesSection        // <-- Now properly implemented
                        Divider().padding(.vertical, 10)
                        metadataSection          // <-- Now properly implemented
                        Divider()
                        customAttributesSection  // <-- Now properly implemented
                        Divider().padding(.vertical, 10)
                        relatedLinksSidebarSection
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
        .sheet(isPresented: $showingLinkEditorSheet) {
            if let project = page.project {
                LinkEditorSheetView(
                    linkTitle: $linkEditorTitle,
                    linkUrlString: $linkEditorURL,
                    project: project,
                    isEditingExistingLink: {
                        if case .sidebarLink(let item) = currentLinkEditingContext { return item != nil }
                        return false
                    }(),
                    onSave: { title, urlString in
                        guard let context = currentLinkEditingContext else { return }
                        switch context {
                        case .mainDescription:
                            textEditorActionProxy.addLink(urlString: urlString)
                        case .sidebarLink(let existingLink):
                            if let linkToUpdate = existingLink {
                                updateSidebarLink(linkToUpdate, title: title, urlString: urlString)
                            } else {
                                addSidebarLink(title: title, urlString: urlString)
                            }
                        }
                    }
                )
            }
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

    // MARK: - Subviews for Sidebar Sections
    private var pageImagesSection: some View {
        VStack(alignment: .leading) {
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
        }
    }

    private var metadataSection: some View {
        Group {
            fieldLabel("Last Modified")
            Text((page.lastModifiedDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
            fieldLabel("Created")
            Text((page.creationDate ?? Date()).formatted(date: .abbreviated, time: .omitted))
        }.padding(.bottom, 5)
    }

    private var customAttributesSection: some View {
        VStack(alignment: .leading) {
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
        }
    }

    private var relatedLinksSidebarSection: some View {
        VStack(alignment: .leading) {
            Text("Related Links").font(.headline)
            if sortedRelatedLinks.isEmpty && !isEditingPage {
               Text("No related links added.").font(.caption).foregroundColor(.gray)
            } else {
               ForEach(sortedRelatedLinks) { linkItem in
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
                       if isEditingPage {
                           Button(action: {
                               currentLinkEditingContext = .sidebarLink(linkItem)
                               linkEditorTitle = linkItem.title ?? ""
                               linkEditorURL = linkItem.urlString ?? ""
                               showingLinkEditorSheet = true
                           }) { Image(systemName: "pencil.circle.fill") }.buttonStyle(BorderlessButtonStyle())
                           Button(action: {
                               deleteSidebarLink(linkItem)
                           }) {
                               Image(systemName: "minus.circle.fill").foregroundColor(.red)
                           }.buttonStyle(BorderlessButtonStyle())
                       }
                   }
                   .padding(.vertical, 2)
                   if linkItem != sortedRelatedLinks.last || isEditingPage { Divider() }
               }
            }
            if isEditingPage {
               Button(action: {
                   currentLinkEditingContext = .sidebarLink(nil)
                   linkEditorTitle = ""
                   linkEditorURL = ""
                   showingLinkEditorSheet = true
               }) { Label("Add Related Link", systemImage: "link.badge.plus") }.padding(.top, 8)
            }
        }
    }

    // MARK: - CRUD methods for Sidebar Related Links (Core Data)
    private func addSidebarLink(title: String?, urlString: String) {
        withAnimation {
            let newLink = RelatedLinkItem(context: viewContext)
            newLink.id = UUID()
            newLink.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty()
            newLink.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            newLink.creationDate = Date()
            newLink.wikiPage = self.page // Link to the current WikiPageItem
            // Consider saving context immediately or as part of savePageChanges()
            // For now, relying on savePageChanges()
        }
    }

    private func updateSidebarLink(_ linkItem: RelatedLinkItem, title: String?, urlString: String) {
        withAnimation {
            viewContext.perform { // Ensure changes are made on the correct context's queue
                linkItem.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty()
                linkItem.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func deleteSidebarLink(_ linkItem: RelatedLinkItem) {
        withAnimation {
            viewContext.delete(linkItem)
        }
    }

    // MARK: - Data Persistence Methods
    private func savePageChanges() {
        let trimmedTitle = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasMeaningfulChanges = false
        if !trimmedTitle.isEmpty && page.title != trimmedTitle {
            page.title = trimmedTitle
            hasMeaningfulChanges = true
        }
        
        if viewContext.hasChanges || hasMeaningfulChanges {
             page.lastModifiedDate = Date()
        }

        if viewContext.hasChanges {
            do {
                try viewContext.save()
                undoManager?.removeAllActions()
            } catch {
                let nsError = error as NSError
                print("Error saving wiki page: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func addWikiPageAttribute() {
        withAnimation {
            let newAttr = WikiPageAttributeItem(context: viewContext)
            newAttr.id = UUID(); newAttr.name = "New Attribute"; newAttr.value = ""; newAttr.creationDate = Date(); newAttr.displayOrder = Int16(wikiPageAttributes.count)
            page.addToAttributes(newAttr)
            // Save happens in savePageChanges
        }
    }

    private func deleteWikiPageAttribute(_ attribute: WikiPageAttributeItem) {
        withAnimation {
            page.removeFromAttributes(attribute); viewContext.delete(attribute)
             // Save happens in savePageChanges
        }
    }

    private func addWikiPageImage(imageData: Data) {
        withAnimation {
            let newImageItem = WikiPageImageItem(context: viewContext)
            newImageItem.id = UUID(); newImageItem.imageData = imageData; newImageItem.creationDate = Date(); newImageItem.displayOrder = Int16(wikiPageImages.count)
            page.addToImages(newImageItem)
            // Save happens in savePageChanges
        }
    }

    private func deleteWikiPageImage(_ imageItem: WikiPageImageItem) {
        withAnimation {
            page.removeFromImages(imageItem); viewContext.delete(imageItem)
            // Save happens in savePageChanges
        }
    }
}
