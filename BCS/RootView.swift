import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label(L10n.t(.tabScanner, lang: settings.language), systemImage: "doc.text.viewfinder")
                }
            
            SettingsView()
                .tabItem {
                    Label(L10n.t(.tabSettings, lang: settings.language), systemImage: "gearshape")
                }
        }
    }
}


