import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        TabView {
            CardListView()
                .tabItem {
                    Label { Text(L10n.t(.tabCards, lang: settings.language)) } icon: {
                        Image(BCSIcon.contacts.rawValue).renderingMode(.template)
                    }
                }
            
            SettingsView()
                .tabItem {
                    Label { Text(L10n.t(.tabSettings, lang: settings.language)) } icon: {
                        Image(BCSIcon.settings.rawValue).renderingMode(.template)
                    }
                }
        }
        .tint(M3.primary)
        .toolbarBackground(M3.surfaceContainer, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
