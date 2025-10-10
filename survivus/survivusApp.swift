import SwiftUI

@main
struct SurvivusApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environment(\.votedOutContestantIDs, app.votedOutContestantIDs)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var authentication = AuthenticationViewModel()

    var body: some View {
        Group {
            if authentication.isAuthenticated {
                MainTabView()
                    .environmentObject(authentication)
                    .transition(.opacity)
            } else {
                AuthenticationView(viewModel: authentication)
                    .transition(.opacity)
            }
        }
        .onChange(of: authentication.authenticatedUserID) { newValue in
            guard let userID = newValue else { return }
            app.selectUser(with: userID)
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        TabView {
            ResultsView()
                .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
            AllPicksView()
                .tabItem { Label("Picks", systemImage: "checkmark.circle") }
            TableView()
                .tabItem { Label("Table", systemImage: "tablecells") }
        }
        .environment(\.votedOutContestantIDs, app.votedOutContestantIDs)
    }
}
