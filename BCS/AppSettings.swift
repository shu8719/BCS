import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case system = "system"
        case japanese = "ja"
        case english = "en"
        
        var id: String { rawValue }
    }
    
    @AppStorage("app_language") var languageRaw: String = Language.system.rawValue
    
    var language: Language {
        get { Language(rawValue: languageRaw) ?? .system }
        set {
            languageRaw = newValue.rawValue
            objectWillChange.send()   // これでUIが確実に更新される
        }
    }
}

