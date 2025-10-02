import SwiftUI

@main
struct survivusApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                ResultsView()
                    .environmentObject(app)
                    .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
                PicksView()
                    .environmentObject(app)
                    .tabItem { Label("Picks", systemImage: "checkmark.square") }
                TableView()
                    .environmentObject(app)
                    .tabItem { Label("Table", systemImage: "tablecells") }
            }
        }
    }
}
