import SwiftUI

/// "N 件を削除しました ／ 取り消す" strip shown for 6 seconds after a delete, on any tab.
struct UndoBar: View {
    @EnvironmentObject private var settings: AppSettings
    let operation: CardStore.UndoOperation
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .textStyle(.bodySmall)
                .foregroundStyle(M3.onSurfaceVariant)
            Spacer()
            BCSButton(L10n.t(.undo, lang: settings.language), style: .tonal, action: action)
        }
        .padding(12)
        .background(M3.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var message: String {
        switch operation {
        case .deleteSingle:          return L10n.t(.undoDeletedMessage, lang: settings.language)
        case .deleteMany(let count): return L10n.t(.undoDeletedManyMessage, lang: settings.language, count)
        case .deleteAll:             return L10n.t(.undoResetMessage, lang: settings.language)
        }
    }
}
