// EditWikiPageView.swift

import SwiftUI
import CoreData

// Helper View to display NSAttributedString in a read-only way
struct ReadOnlyRichTextView: View {
    let rtfData: Data?

    var attributedString: AttributedString? {
        guard let data = rtfData,
              let nsAttrStr = NSAttributedString(rtf: data, documentAttributes: nil) else {
            return nil
        }
        return AttributedString(nsAttrStr)
    }

    var body: some View {
        if let attrString = attributedString, !attrString.runs.isEmpty {
            Text(attrString)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("(No content for this page)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


struct EditWikiPageView: View {
    @ObservedObject var page: WikiPageItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.undoManager) var undoManager // Get the undo manager from the environment

    @State private var editableTitle: String
    @State private var isEditingPage: Bool = false
    
    @StateObject private var textEditorCoordinator: RichTextCoordinator

    @State private var showingAddLinkSheet = false
    @State private var linkURLInput: String = ""

    private var pageAttributes: [WikiPageAttributeItem] {
        let unsortedAttributes = page.attributes as? Set<WikiPageAttributeItem> ?? []
        return unsortedAttributes.sorted {
            if $0.displayOrder != $1.displayOrder {
                return $0.displayOrder < $1.displayOrder
            }
            return ($0.name ?? "") < ($1.name ?? "")
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
        Text(label)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.bottom, -2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if isEditingPage {
                    Button("Save Page") {
                        savePageChanges()
                        isEditingPage = false
                    }
                    .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Edit Page") {
                        editableTitle = page.title ?? ""
                        isEditingPage = true
                    }
                }
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)

            if isEditingPage {
                HStack(spacing: 15) {
                    Button(action: { textEditorCoordinator.toggleBold() }) { Image(systemName: "bold") }
                    Button(action: { textEditorCoordinator.toggleItalic() }) { Image(systemName: "italic") }
                    Button(action: {
                        linkURLInput = ""
                        showingAddLinkSheet = true
                    }) { Image(systemName: "link") }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            HSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if isEditingPage {
                            TextField("Page Title", text: $editableTitle, prompt: Text("Enter page title"))
                        } else {
                            Text(page.title ?? "Untitled Page")
                                .textSelection(.enabled)
                        }
                    }
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .padding([.horizontal, .top])
                    .padding(.bottom, 10)
                    
                    Divider().padding(.horizontal)

                    if isEditingPage {
                        RichTextEditorView(rtfData: $page.contentRTFData, coordinator: textEditorCoordinator)
                            .padding(.top, 5)
                    } else {
                        ScrollView {
                            ReadOnlyRichTextView(rtfData: page.contentRTFData)
                                .padding()
                        }
                    }
                }
                .frame(minWidth: 350, idealWidth: 700, maxWidth: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Details")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Divider()

                        // UPDATED: Using .formatted() for date display
                        fieldLabel("Last Modified")
                        Text((page.lastModifiedDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                        fieldLabel("Created")
                        Text((page.creationDate ?? Date()).formatted(date: .abbreviated, time: .omitted))
                            .padding(.bottom, 5)
                        
                        Divider()
                        
                        Text("Attributes").font(.headline)
                        
                        if pageAttributes.isEmpty && !isEditingPage {
                            Text("No attributes defined.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            ForEach(pageAttributes) { attribute in
                                VStack(alignment: .leading, spacing: 2) {
                                    if isEditingPage {
                                        HStack {
                                            TextField("Attribute Name", text: Binding(
                                                get: { attribute.name ?? "" },
                                                set: { newValue in
                                                    undoManager?.registerUndo(withTarget: attribute) { target in target.name = attribute.name }
                                                    attribute.name = newValue
                                                }
                                            ), prompt: Text("Name"))
                                            .textFieldStyle(PlainTextFieldStyle())
                                            Spacer()
                                            Button(action: { deleteAttribute(attribute) }) {
                                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        TextField("Value", text: Binding(
                                            get: { attribute.value ?? "" },
                                            set: { newValue in
                                                undoManager?.registerUndo(withTarget: attribute) { target in target.value = attribute.value }
                                                attribute.value = newValue
                                            }
                                        ), prompt: Text("Value"))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: NSFont.systemFontSize(for: .small)))
                                    } else {
                                        Text(attribute.name ?? "Unnamed Attribute").fontWeight(.semibold)
                                        Text(attribute.value ?? "-").font(.subheadline)
                                    }
                                }
                                .padding(.vertical, 4)
                                if attribute != pageAttributes.last || isEditingPage {
                                    Divider()
                                }
                            }
                        }

                        if isEditingPage {
                            Button(action: addAttribute) {
                                Label("Add Attribute", systemImage: "plus.circle.fill")
                            }
                            .padding(.top, 8)
                        }
                        
                        Divider().padding(.vertical, 10)

                        Group {
                            Text("Attached Images").font(.headline)
                            Text("Image functionality (To be implemented)")
                                .font(.caption).foregroundColor(.gray).padding(.bottom, 10)
                            Text("Related Links").font(.headline)
                            Text("Structured links list (To be implemented)")
                                .font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .frame(width: 320)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: page) { oldPage, newPage in // Updated for newer iOS/macOS versions
            if oldPage.id != newPage.id {
                 editableTitle = newPage.title ?? ""
            } else if !isEditingPage { // If same page, but external changes, and not editing
                editableTitle = newPage.title ?? ""
            }
        }
        .sheet(isPresented: $showingAddLinkSheet) {
            VStack(spacing: 15) {
                Text("Add Link").font(.headline).padding(.top)
                Text("Selected text will be linked. If no text is selected, this may not apply.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Enter URL (e.g., https://www.example.com)", text: $linkURLInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button("Cancel") { showingAddLinkSheet = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Apply Link") {
                        if !linkURLInput.isEmpty {
                            textEditorCoordinator.addLink(urlString: linkURLInput)
                        }
                        showingAddLinkSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(minWidth: 350, idealWidth: 450, minHeight: 180)
        }
        // REMOVED: .environment(\.undoManager, viewContext.undoManager)
        // Relies on the @Environment(\.undoManager) var undoManager above to pick up
        // the undo manager from the viewContext if it's set higher up in the hierarchy.
    }

    private func addAttribute() {
        withAnimation {
            let newAttribute = WikiPageAttributeItem(context: viewContext)
            newAttribute.id = UUID()
            newAttribute.name = "New Attribute"
            newAttribute.value = ""
            newAttribute.creationDate = Date()
            newAttribute.displayOrder = Int16(pageAttributes.count)
            
            page.addToAttributes(newAttribute)
            
            undoManager?.registerUndo(withTarget: page, handler: { targetPage in
                targetPage.removeFromAttributes(newAttribute)
                viewContext.delete(newAttribute)
            })
        }
    }

    private func deleteAttribute(_ attribute: WikiPageAttributeItem) {
        withAnimation {
            let oldName = attribute.name
            let oldValue = attribute.value
            let oldDisplayOrder = attribute.displayOrder
            let oldCreationDate = attribute.creationDate
            let attributeID = attribute.id
            
            page.removeFromAttributes(attribute)
            viewContext.delete(attribute)
            
            undoManager?.registerUndo(withTarget: page, handler: { targetPage in
                let recreatedAttribute = WikiPageAttributeItem(context: viewContext)
                recreatedAttribute.id = attributeID
                recreatedAttribute.name = oldName
                recreatedAttribute.value = oldValue
                recreatedAttribute.displayOrder = oldDisplayOrder
                recreatedAttribute.creationDate = oldCreationDate
                targetPage.addToAttributes(recreatedAttribute)
            })
        }
    }

    private func savePageChanges() {
        let trimmedTitle = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasMeaningfulChanges = false

        if !trimmedTitle.isEmpty && page.title != trimmedTitle {
            page.title = trimmedTitle
            hasMeaningfulChanges = true
        }
        
        if viewContext.hasChanges {
            hasMeaningfulChanges = true
        }
        
        if hasMeaningfulChanges {
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
}
