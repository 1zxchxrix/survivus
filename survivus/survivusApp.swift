//
//  survivusApp.swift
//  survivus
//
//  Created by Zacharia Salad on 10/1/25.
//

import SwiftUI

@main
struct survivusApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
