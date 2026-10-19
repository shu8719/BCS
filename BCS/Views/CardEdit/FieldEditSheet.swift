import SwiftUI

/// Small sheet that edits a single value (used by the scan result screen).
struct FieldEditSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    @State private var value: String
    var multiline: Bool = false
    var keyboard: UIKeyboardType = .default
    let onSave: (String) -> Void
    
    init(title: String, value: String, multiline: Bool = false, keyboard: UIKeyboardType = .default,
         onSave: @escaping (String) -> Void) {
        self.title = title
        _value = State(initialValue: value)
        self.multiline = multiline
        self.keyboard = keyboard
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            M3.surface.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack(spacing: 4) {
                    IconButton(.close) { dismiss() }
                    Text(title)
                        .textStyle(.titleLarge)
                        .foregroundStyle(M3.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BCSButton(L10n.t(.save, lang: settings.language), style: .filled) {
                        onSave(value)
                        dismiss()
                    }
                }
                .padding(.leading, 4)
                .padding(.trailing, 16)
                .padding(.top, 8)
                OutlinedTextField(label: title, text: $value, multiline: multiline, keyboard: keyboard)
                    .padding(.horizontal, 16)
                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}
