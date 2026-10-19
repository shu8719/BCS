import SwiftUI

@main
struct BCSApp: App {
    @State private var store = CardStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environmentObject(settings)
        }
    }
}

