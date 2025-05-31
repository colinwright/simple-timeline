// Persistence.swift

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor // Good practice for preview data accessed by UI
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // TODO: Consider replacing this with sample data relevant to your app's entities
        // For example, create a sample ProjectItem and some WikiPageItems
        let sampleProject = ProjectItem(context: viewContext)
        sampleProject.id = UUID()
        sampleProject.title = "Preview Project"
        sampleProject.creationDate = Date()

        let page1 = WikiPageItem(context: viewContext)
        page1.id = UUID()
        page1.title = "Sample Preview Wiki Page"
        page1.creationDate = Date()
        page1.lastModifiedDate = Date()
        if let rtfData = NSAttributedString(string: "Some initial content for preview.").rtf(from: NSRange(location: 0, length: 10), documentAttributes: [:]) { // Basic RTF
            page1.contentRTFData = rtfData
        }
        page1.project = sampleProject
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SimpleTimeline")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                // You should not use this function in a shipping application,
                // although it may be useful during development.
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        // **CRITICAL ADDITION FOR UNDO SUPPORT**
        container.viewContext.undoManager = UndoManager()
    }
}
