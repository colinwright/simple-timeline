import SwiftUI
import CoreData

struct CharacterListView: View {
    @ObservedObject var project: ProjectItem
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selection: MainViewSelection // For main breadcrumb navigation

    @FetchRequest private var characters: FetchedResults<CharacterItem>

    @State private var selectedCharacter: CharacterItem?
    @State private var showingAddCharacterView = false
    @State private var isCharacterListVisible: Bool = true

    private let listHeaderHeight: CGFloat = 30 + (2 * 4) // Consistent with WikiView

    init(project: ProjectItem, selection: Binding<MainViewSelection>) {
        _project = ObservedObject(initialValue: project)
        _selection = selection
        _characters = FetchRequest<CharacterItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CharacterItem.name, ascending: true)],
            predicate: NSPredicate(format: "project == %@", project),
            animation: .default)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { // Root VStack
            DetailViewHeader {
                BreadcrumbView(
                    projectTitle: project.title ?? "Untitled Project",
                    currentViewName: "Characters",
                    isProjectTitleClickable: true,
                    projectHomeAction: { selection = .projectHome }
                )
            } trailing: {
                Button {
                    showingAddCharacterView = true
                } label: {
                    Label("Add Character", systemImage: "person.fill.badge.plus")
                }
            }

            HStack(spacing: 0) { // Master-Detail
                // Master Pane: Character List (Collapsible)
                if isCharacterListVisible {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Characters")
                                .font(.title3)
                                .padding(.leading)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCharacterListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.left.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing)
                        }
                        .frame(height: 30)
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        List { // Removed selection binding for manual tap
                            ForEach(characters) { character in
                                HStack {
                                    if let hex = character.colorHex, let color = Color(hex: hex) {
                                        Circle().fill(color).frame(width: 10, height: 10)
                                    }
                                    Text(character.name ?? "Unnamed Character")
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedCharacter == character ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCharacter = character
                                }
                            }
                            .onDelete(perform: deleteCharacters)
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(width: 240)
                    .transition(.move(edge: .leading))
                    Divider()
                }

                // Detail Pane
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if !isCharacterListVisible {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCharacterListVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.right.square.fill")
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading)
                        }
                        Spacer()
                    }
                    .frame(height: listHeaderHeight)
                    .opacity(!isCharacterListVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isCharacterListVisible)

                    Group {
                        if let char = selectedCharacter {
                            EditCharacterView(character: char) // Use the refactored EditCharacterView
                                .id(char.id)
                        } else {
                            VStack {
                                Spacer()
                                Text(characters.isEmpty ? "No characters yet." : "Select a character to view details.")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                if characters.isEmpty {
                                    Text("Click 'Add Character' in the header to start.")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddCharacterView) {
            AddCharacterView(project: project)
        }
        .onChange(of: selectedCharacter) { oldValue, newValue in
            // print("Selected character changed to: \(newValue?.name ?? "None")")
        }
    }
    
    private func deleteCharacters(offsets: IndexSet) {
        withAnimation {
            offsets.map { characters[$0] }.forEach { characterToDelete in
                if selectedCharacter == characterToDelete {
                    selectedCharacter = nil
                }
                viewContext.delete(characterToDelete)
            }
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error deleting characters: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct CharacterListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleProject = ProjectItem(context: context)
        sampleProject.title = "Sample Project"
        
        let char1 = CharacterItem(context: context); char1.name = "Alice"; char1.colorHex = "#FF0000"; char1.project = sampleProject
        let char2 = CharacterItem(context: context); char2.name = "Bob"; char2.colorHex = "#00FF00"; char2.project = sampleProject

        return CharacterListView(project: sampleProject, selection: .constant(.characters))
            .environment(\.managedObjectContext, context)
            .frame(width: 900, height: 700)
    }
}
