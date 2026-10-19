    import SwiftUI

@main
struct BCSApp: App {
    @State private var store: CardStore = {
        #if DEBUG
        if DebugLaunch.usesTemporaryStore {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("uitest-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return CardStore(directory: dir)
        }
        #endif
        return CardStore()
    }()
    @StateObject private var settings = AppSettings()
    
    init() {
        // Unselected tab color is not reachable from SwiftUI modifiers.
        UITabBar.appearance().unselectedItemTintColor = UIColor(named: "on-surface-variant")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environmentObject(settings)
        }
    }
}
