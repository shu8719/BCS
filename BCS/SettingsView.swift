import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.t(.language, lang: settings.language))) {
                    Picker("", selection: $settings.languageRaw) {
                        Text(L10n.t(.system, lang: settings.language)).tag(AppSettings.Language.system.rawValue)
                        Text(L10n.t(.japanese, lang: settings.language)).tag(AppSettings.Language.japanese.rawValue)
                        Text(L10n.t(.english, lang: settings.language)).tag(AppSettings.Language.english.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle(L10n.t(.settingsTitle, lang: settings.language))
        }
    }
}

