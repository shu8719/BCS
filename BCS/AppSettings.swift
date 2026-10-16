import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case system = "system"
        case japanese = "ja"
        case english = "en"
        
        var id: String { rawValue }
    }
    
    private static let storageKey = "app_language"
    
    // Single source of truth: @Published drives view updates, didSet persists.
    @Published var language: Language {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }
    
    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        language = Language(rawValue: raw) ?? .system
    }
}
