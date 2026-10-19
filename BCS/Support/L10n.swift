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

        // Card list (01)
        case tabCards
        case searchPlaceholder
        case filterAll, filterNeedsReview, filterCompany, filterTimeZone
        case allCompanies, allTimeZones
        case groupThisWeek, groupEarlier, countSuffix, localTime
        case sortTitle, sortNewest, sortName, sortCompany

        // Selection mode (02)
        case selectedCount, tapToToggle, selectAll, exportSelectedCSV, undoDeletedManyMessage, deleteCountTitle

        // Card detail (03)
        case contactInfo, reviewItemsTitle, markReviewed, reviewSuffix
        case reviewNoteNormalized, reviewNoteMissing, reviewNoteTZConflict
        case reviewSubtitleNormalized, reviewSubtitleMissing
        case actionCall, actionMail, actionMap
        case phoneDirect, phoneMain, phoneMobile, phoneGeneric
        case localTimeLine, scannedOn, tzFromZip, tzFromAreaCode, tzManual, deleteThisCard

        // Card edit (04)
        case editCardTitle, phoneN, phoneWithLabel
        case tzAuto, tzUnknown, tzNameEST, tzNameCST, tzNameMST, tzNamePST, tzBasisZip, tzBasisAreaCode

        // Scan result (06) and scan entry
        case scanResultTitle, readFieldsCount, tapToFix, bannerNormalizedPhone, bannerMissing
        case retake, saveCard, scanWithCamera, scanFromPhoto, tzFromZipShort, tzFromAreaCodeShort, photoLoadFailed

        // Settings (07)
        case sectionDisplay, sectionData, sectionDeveloper, exportCSVTitle, cardsCount, deleteAllCards
    }

    /// Formats a key that contains %d / %@ placeholders.
    static func t(_ key: Key, lang: AppSettings.Language, _ args: CVarArg...) -> String {
        String(format: t(key, lang: lang), locale: Locale(identifier: "en_US_POSIX"), arguments: args)
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

            case .tabCards: return "名刺"
            case .searchPlaceholder: return "名前・会社・メールで検索"
            case .filterAll: return "すべて"
            case .filterNeedsReview: return "要確認"
            case .filterCompany: return "会社"
            case .filterTimeZone: return "時間帯"
            case .allCompanies: return "すべての会社"
            case .allTimeZones: return "すべての時間帯"
            case .groupThisWeek: return "今週"
            case .groupEarlier: return "それ以前"
            case .countSuffix: return "%d件"
            case .localTime: return "現地 %@"
            case .sortTitle: return "並び替え"
            case .sortNewest: return "新しい順"
            case .sortName: return "名前順"
            case .sortCompany: return "会社順"

            case .selectedCount: return "%d 件を選択中"
            case .tapToToggle: return "タップで選択を切り替え"
            case .selectAll: return "すべて選択"
            case .exportSelectedCSV: return "CSVで書き出す"
            case .undoDeletedManyMessage: return "%d 件を削除しました"
            case .deleteCountTitle: return "%d 件を削除しますか？"

            case .contactInfo: return "連絡先情報"
            case .reviewItemsTitle: return "要確認の項目が %d 件あります"
            case .markReviewed: return "確認済みに"
            case .reviewSuffix: return " ・ 要確認"
            case .reviewNoteNormalized: return "読み取り元: %@ → 補正済み"
            case .reviewNoteMissing: return "読み取れませんでした"
            case .reviewNoteTZConflict: return "郵便番号と市外局番の判定が異なります"
            case .reviewSubtitleNormalized: return "読み取り時に書式を補正しました"
            case .reviewSubtitleMissing: return "読み取れなかった項目があります"
            case .actionCall: return "電話"
            case .actionMail: return "メール"
            case .actionMap: return "地図"
            case .phoneDirect: return "直通"
            case .phoneMain: return "代表"
            case .phoneMobile: return "携帯"
            case .phoneGeneric: return "電話"
            case .localTimeLine: return "現地時刻 %@ ・ 日本との時差 %@時間"
            case .scannedOn: return "%@ にスキャン"
            case .tzFromZip: return "郵便番号 %@ からタイムゾーンを自動判定"
            case .tzFromAreaCode: return "市外局番 %@ からタイムゾーンを自動判定"
            case .tzManual: return "タイムゾーンは手動設定"
            case .deleteThisCard: return "この名刺を削除"

            case .editCardTitle: return "名刺を編集"
            case .phoneN: return "電話 %d"
            case .phoneWithLabel: return "電話（%@）"
            case .tzAuto: return "タイムゾーン（自動判定）"
            case .tzUnknown: return "未判定"
            case .tzNameEST: return "東部標準時"
            case .tzNameCST: return "中部標準時"
            case .tzNameMST: return "山岳部標準時"
            case .tzNamePST: return "太平洋標準時"
            case .tzBasisZip: return "郵便番号 %@ から判定"
            case .tzBasisAreaCode: return "市外局番 %@ から判定"

            case .scanResultTitle: return "読み取り結果"
            case .readFieldsCount: return "%d項目を読み取りました"
            case .tapToFix: return "タップで修正"
            case .bannerNormalizedPhone: return "電話番号「%@」を整形しました。保存前に確認してください。"
            case .bannerMissing: return "名前または会社名を読み取れませんでした。"
            case .retake: return "撮り直す"
            case .saveCard: return "保存する"
            case .scanWithCamera: return "カメラでスキャン"
            case .scanFromPhoto: return "写真から"
            case .tzFromZipShort: return "郵便番号 %@ からタイムゾーンを判定"
            case .tzFromAreaCodeShort: return "市外局番 %@ からタイムゾーンを判定"
            case .photoLoadFailed: return "画像を読み込めませんでした"

            case .sectionDisplay: return "表示"
            case .sectionData: return "データ"
            case .sectionDeveloper: return "開発用（DEBUG ビルドのみ）"
            case .exportCSVTitle: return "CSVで書き出す"
            case .cardsCount: return "%d件の名刺"
            case .deleteAllCards: return "すべての名刺を削除"
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

            case .tabCards: return "Cards"
            case .searchPlaceholder: return "Search name, company, email"
            case .filterAll: return "All"
            case .filterNeedsReview: return "Needs review"
            case .filterCompany: return "Company"
            case .filterTimeZone: return "Time zone"
            case .allCompanies: return "All companies"
            case .allTimeZones: return "All time zones"
            case .groupThisWeek: return "This week"
            case .groupEarlier: return "Earlier"
            case .countSuffix: return "%d"
            case .localTime: return "Local %@"
            case .sortTitle: return "Sort"
            case .sortNewest: return "Newest first"
            case .sortName: return "By name"
            case .sortCompany: return "By company"

            case .selectedCount: return "%d selected"
            case .tapToToggle: return "Tap to toggle"
            case .selectAll: return "Select all"
            case .exportSelectedCSV: return "Export CSV"
            case .undoDeletedManyMessage: return "%d cards deleted"
            case .deleteCountTitle: return "Delete %d cards?"

            case .contactInfo: return "Contact info"
            case .reviewItemsTitle: return "%d items need review"
            case .markReviewed: return "Mark reviewed"
            case .reviewSuffix: return " · Needs review"
            case .reviewNoteNormalized: return "Read as: %@ → normalized"
            case .reviewNoteMissing: return "Could not be read"
            case .reviewNoteTZConflict: return "ZIP and area code disagree"
            case .reviewSubtitleNormalized: return "Formatting was corrected on scan"
            case .reviewSubtitleMissing: return "Some fields could not be read"
            case .actionCall: return "Call"
            case .actionMail: return "Email"
            case .actionMap: return "Map"
            case .phoneDirect: return "Direct"
            case .phoneMain: return "Main"
            case .phoneMobile: return "Mobile"
            case .phoneGeneric: return "Phone"
            case .localTimeLine: return "Local %@ · %@h from Japan"
            case .scannedOn: return "Scanned %@"
            case .tzFromZip: return "Time zone from ZIP %@"
            case .tzFromAreaCode: return "Time zone from area code %@"
            case .tzManual: return "Time zone set manually"
            case .deleteThisCard: return "Delete this card"

            case .editCardTitle: return "Edit card"
            case .phoneN: return "Phone %d"
            case .phoneWithLabel: return "Phone (%@)"
            case .tzAuto: return "Time zone (auto)"
            case .tzUnknown: return "Unknown"
            case .tzNameEST: return "Eastern Time"
            case .tzNameCST: return "Central Time"
            case .tzNameMST: return "Mountain Time"
            case .tzNamePST: return "Pacific Time"
            case .tzBasisZip: return "From ZIP %@"
            case .tzBasisAreaCode: return "From area code %@"

            case .scanResultTitle: return "Scan result"
            case .readFieldsCount: return "%d fields read"
            case .tapToFix: return "Tap to fix"
            case .bannerNormalizedPhone: return "Phone number “%@” was reformatted. Check it before saving."
            case .bannerMissing: return "Name or company could not be read."
            case .retake: return "Retake"
            case .saveCard: return "Save"
            case .scanWithCamera: return "Scan with camera"
            case .scanFromPhoto: return "From photo"
            case .tzFromZipShort: return "Time zone from ZIP %@"
            case .tzFromAreaCodeShort: return "Time zone from area code %@"
            case .photoLoadFailed: return "Could not load the image"

            case .sectionDisplay: return "Display"
            case .sectionData: return "Data"
            case .sectionDeveloper: return "Developer (DEBUG only)"
            case .exportCSVTitle: return "Export CSV"
            case .cardsCount: return "%d cards"
            case .deleteAllCards: return "Delete all cards"
            }
        }
    }
}
