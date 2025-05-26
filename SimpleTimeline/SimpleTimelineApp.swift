//
//  SimpleTimelineApp.swift
//  SimpleTimeline
//
//  Created by Colin Wright on 5/26/25.
//

import SwiftUI

@main
struct SimpleTimelineApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
