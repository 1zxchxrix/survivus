import SwiftUI

@main
struct SurvivusApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                ResultsView()
                    .environmentObject(app)
                    .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
                AllPicksView()
                    .environmentObject(app)
                    .tabItem { Label("Picks", systemImage: "checkmark.circle") }
                TableView()
                    .environmentObject(app)
                    .tabItem { Label("Table", systemImage: "tablecells") }
            }
            .environment(\.votedOutContestantIDs, app.votedOutContestantIDs)
        }
    }
}
