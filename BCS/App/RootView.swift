import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        TabView {
            CardListView()
                .tabItem {
                    Label(L10n.t(.tabCards, lang: settings.language), systemImage: "person.2")
                }
            
            SettingsView()
                .tabItem {
                    Label(L10n.t(.tabSettings, lang: settings.language), systemImage: "gearshape")
                }
        }
    }
}


