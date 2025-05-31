// LinkEditorSheetView.swift

import SwiftUI
import CoreData

enum InternalLinkTargetType: String, CaseIterable, Identifiable {
    case wikiPage = "Wiki Page"
    case character = "Character"
    // Future: case event = "Event"
    var id: String { self.rawValue }
}

struct LinkEditorSheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @Binding var linkTitle: String
    @Binding var linkUrlString: String
    
    @State private var selectedLinkMode: LinkMode = .external
    @State private var selectedInternalTargetType: InternalLinkTargetType = .wikiPage
    @State private var selectedWikiPageID: UUID?
    @State private var selectedCharacterID: UUID?

    enum LinkMode: String, CaseIterable, Identifiable {
        case external = "External URL"
        case internalLink = "Internal Link to Project Item"
        var id: String { self.rawValue }
    }
    
    let project: ProjectItem
    var onSave: (_ title: String, _ urlString: String) -> Void
    var isEditingExistingLink: Bool

    @FetchRequest private var wikiPages: FetchedResults<WikiPageItem>
    @FetchRequest private var characters: FetchedResults<CharacterItem>

    init(linkTitle: Binding<String>,
         linkUrlString: Binding<String>,
         project: ProjectItem,
         isEditingExistingLink: Bool = false,
         onSave: @escaping (_ title: String, _ urlString: String) -> Void) {
        self._linkTitle = linkTitle
        self._linkUrlString = linkUrlString
        self.project = project
        self.isEditingExistingLink = isEditingExistingLink
        self.onSave = onSave

        let projectPredicate = NSPredicate(format: "project == %@", project)
        _wikiPages = FetchRequest<WikiPageItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \WikiPageItem.title, ascending: true)],
            predicate: projectPredicate
        )
        _characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: projectPredicate
        )
    }

    private func populateStateFromExistingLink() {
        // The 'url' variable here is used for its properties (scheme, host, lastPathComponent).
        // The warning "Value 'url' was defined but never used" can be a false positive in such cases.
        if let url = URL(string: linkUrlString), url.scheme == "simpletl" {
            selectedLinkMode = .internalLink
            let host = url.host
            let idString = url.lastPathComponent
            
            if host == "wikipage", let uuid = UUID(uuidString: idString) {
                selectedInternalTargetType = .wikiPage
                selectedWikiPageID = uuid
            } else if host == "character", let uuid = UUID(uuidString: idString) {
                selectedInternalTargetType = .character
                selectedCharacterID = uuid
            }
        } else {
            selectedLinkMode = .external
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Link Details")) {
                    TextField("Display Title (Optional)", text: $linkTitle)
                    
                    Picker("Link Type", selection: $selectedLinkMode) {
                        ForEach(LinkMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                if selectedLinkMode == .external {
                    Section(header: Text("External URL")) {
                        TextField("https://www.example.com", text: $linkUrlString)
                            .disableAutocorrection(true)
                    }
                } else { // .internalLink
                    Section(header: Text("Link to Project Item")) {
                        Picker("Item Type", selection: $selectedInternalTargetType) {
                            ForEach(InternalLinkTargetType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        // UPDATED: Using the newer .onChange signature
                        .onChange(of: selectedInternalTargetType) { oldValue, newValue in
                            clearSpecificItemSelection(newValue)
                        }

                        if selectedInternalTargetType == .wikiPage {
                            if wikiPages.isEmpty {
                                Text("No wiki pages in this project.").foregroundColor(.secondary)
                            } else {
                                Picker("Select Wiki Page", selection: $selectedWikiPageID) {
                                    Text("None Selected").tag(nil as UUID?)
                                    ForEach(wikiPages) { page in
                                        Text(page.title ?? "Untitled Page").tag(page.id as UUID?)
                                    }
                                }
                            }
                        } else if selectedInternalTargetType == .character {
                            if characters.isEmpty {
                                Text("No characters in this project.").foregroundColor(.secondary)
                            } else {
                                Picker("Select Character", selection: $selectedCharacterID) {
                                    Text("None Selected").tag(nil as UUID?)
                                    ForEach(characters) { char in
                                        Text(char.name ?? "Unnamed Character").tag(char.id as UUID?)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditingExistingLink ? "Edit Link" : "Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { processAndSaveLink() }
                    .disabled(!isLinkValid())
                }
            }
            .onAppear {
                if isEditingExistingLink {
                    populateStateFromExistingLink()
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 300, idealHeight: 350)
    }
    
    private func clearSpecificItemSelection(_ newType: InternalLinkTargetType) {
        selectedWikiPageID = nil
        selectedCharacterID = nil
    }

    private func processAndSaveLink() {
        var finalURLString = ""
        var finalTitle = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedLinkMode == .external {
            finalURLString = linkUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if finalTitle.isEmpty { finalTitle = finalURLString }
        } else {
            if selectedInternalTargetType == .wikiPage, let pageID = selectedWikiPageID {
                finalURLString = "simpletl://wikipage/\(pageID.uuidString)"
                if finalTitle.isEmpty, let page = wikiPages.first(where: {$0.id == pageID}) { finalTitle = page.title ?? finalURLString }
            } else if selectedInternalTargetType == .character, let charID = selectedCharacterID {
                finalURLString = "simpletl://character/\(charID.uuidString)"
                 if finalTitle.isEmpty, let char = characters.first(where: {$0.id == charID}) { finalTitle = char.name ?? finalURLString }
            }
        }
        
        if finalTitle.isEmpty {
            finalTitle = finalURLString.isEmpty ? "Untitled Link" : finalURLString
        }

        onSave(finalTitle, finalURLString)
        dismiss()
    }

    private func isLinkValid() -> Bool {
        if selectedLinkMode == .external {
            let trimmedURL = linkUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURL.isEmpty else { return false }
            if trimmedURL.starts(with: "simpletl://") { return true }
            return URL(string: trimmedURL) != nil
        } else {
            return (selectedInternalTargetType == .wikiPage && selectedWikiPageID != nil) ||
                   (selectedInternalTargetType == .character && selectedCharacterID != nil)
        }
    }
}
