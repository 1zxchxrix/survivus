import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct SurvivusApp: App {
    @StateObject private var app = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Make URLSession caching actually useful for images
        let mem = 50 * 1024 * 1024   // 50 MB
        let disk = 200 * 1024 * 1024 // 200 MB
        URLCache.shared = URLCache(memoryCapacity: mem, diskCapacity: disk, directory: nil)
    }

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
    @State private var selectedTab: Tab = .picks

    var body: some View {
        TabView(selection: $selectedTab) {
            ResultsView()
                .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
                .tag(Tab.results)
            AllPicksView()
                .tabItem { Label("Picks", systemImage: "checkmark.circle") }
                .tag(Tab.picks)
            TableView()
                .tabItem { Label("Table", systemImage: "tablecells") }
                .tag(Tab.table)
        }
        .environment(\.votedOutContestantIDs, app.votedOutContestantIDs)
    }
}

private extension MainTabView {
    enum Tab { case results, picks, table }
}
