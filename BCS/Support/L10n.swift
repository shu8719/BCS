import Foundation

struct L10n {
    enum Key: String {
        case title
        case scan, edit
        case deleteSelected, resetAllCards
        case deleteSelectedTitle, deleteSelectedMessage
        case resetAllTitle, resetAllMessage
        case deleteAction, resetAction
        case undo, undoDeletedMessage, undoResetMessage, emptyCardsMessage
        case timeZone
        
        case name, company, phone, email, address
        
        case tabScanner, tabSettings
        case settingsTitle, language
        case system, japanese, english
        
        case addPhone
        case clearAll
        case cancel, save
        case ok

        case scanEmptyTitle, scanEmptyMessage
        case scanFailedTitle, scanFailedMessage

        case exportCSV
        case needsReview, rawValue
    }
    
    /// Maps `.system` to the concrete language the device prefers.
    static func resolve(_ lang: AppSettings.Language) -> AppSettings.Language {
        if lang != .system { return lang }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ja") ? .japanese : .english
    }
    
    static func t(_ key: Key, lang: AppSettings.Language) -> String {
        switch resolve(lang) {
        case .japanese:
            switch key {
            case .title: return "名刺スキャナー"
            case .scan: return "スキャン"
            case .edit: return "編集"
            case .deleteSelected: return "選択を削除"
            case .resetAllCards: return "全削除"
            case .deleteSelectedTitle: return "選択した名刺を削除しますか？"
            case .deleteSelectedMessage: return "削除後 6 秒以内なら「取り消す」で復元できます。"
            case .resetAllTitle: return "すべての名刺を削除しますか？"
            case .resetAllMessage: return "削除後 6 秒以内なら「取り消す」で復元できます。"
            case .deleteAction: return "削除"
            case .resetAction: return "全削除"
            case .undo: return "取り消す"
            case .undoDeletedMessage: return "名刺を削除しました"
            case .undoResetMessage: return "すべての名刺を削除しました"
            case .emptyCardsMessage: return "まだ名刺がありません。スキャンしてください。"
            case .timeZone: return "タイムゾーン"
                
            case .name: return "名前"
            case .company: return "会社"
            case .phone: return "電話"
            case .email: return "メール"
            case .address: return "住所"
                
            case .tabScanner: return "スキャナー"
            case .tabSettings: return "設定"
                
            case .settingsTitle: return "設定"
            case .language: return "言語"
            case .system: return "端末に合わせる"
            case .japanese: return "日本語"
            case .english: return "英語"
                
            case .addPhone: return "電話を追加"
            case .clearAll: return "全消去"
                
            case .cancel: return "キャンセル"
            case .save: return "保存"
            case .ok: return "OK"

            case .scanEmptyTitle: return "テキストが検出されませんでした"
            case .scanEmptyMessage: return "名刺をカメラに正対させて、もう一度お試しください。"
            case .scanFailedTitle: return "スキャンに失敗しました"
            case .scanFailedMessage: return "もう一度お試しください。"

            case .exportCSV: return "CSV出力"
            case .needsReview: return "要確認"
            case .rawValue: return "読み取り元"
            }
            
        case .english, .system:
            switch key {
            case .title: return "Business Card Scanner"
            case .scan: return "Scan"
            case .edit: return "Edit"
            case .deleteSelected: return "Delete Selected"
            case .resetAllCards: return "Clear All"
            case .deleteSelectedTitle: return "Delete selected card?"
            case .deleteSelectedMessage: return "You can undo this for 6 seconds after deleting."
            case .resetAllTitle: return "Delete all cards?"
            case .resetAllMessage: return "You can undo this for 6 seconds after deleting."
            case .deleteAction: return "Delete"
            case .resetAction: return "Delete All"
            case .undo: return "Undo"
            case .undoDeletedMessage: return "Card deleted"
            case .undoResetMessage: return "All cards deleted"
            case .emptyCardsMessage: return "No cards yet. Scan to add one."
            case .timeZone: return "Time Zone"
                
            case .name: return "Name"
            case .company: return "Company"
            case .phone: return "Phone"
            case .email: return "Email"
            case .address: return "Address"
                
            case .tabScanner: return "Scanner"
            case .tabSettings: return "Settings"
                
            case .settingsTitle: return "Settings"
            case .language: return "Language"
            case .system: return "System"
            case .japanese: return "Japanese"
            case .english: return "English"
                
            case .addPhone: return "Add Phone"
            case .clearAll: return "Clear All"
                
            case .cancel: return "Cancel"
            case .save: return "Save"
            case .ok: return "OK"

            case .scanEmptyTitle: return "No text detected"
            case .scanEmptyMessage: return "Make sure the card is facing the camera and try again."
            case .scanFailedTitle: return "Scan failed"
            case .scanFailedMessage: return "Please try again."

            case .exportCSV: return "Export CSV"
            case .needsReview: return "Needs review"
            case .rawValue: return "Raw value"
            }
        }
    }
}
