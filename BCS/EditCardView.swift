import SwiftUI

struct EditCardView: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding var card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BusinessCard()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.t(.name, lang: settings.language))) {
                    TextField(L10n.t(.name, lang: settings.language), text: $draft.name)
                        .autocorrectionDisabled()
                }

                Section(header: Text(L10n.t(.company, lang: settings.language))) {
                    TextField(L10n.t(.company, lang: settings.language), text: $draft.company)
                        .autocorrectionDisabled()
                }

                Section(header: Text(L10n.t(.phone, lang: settings.language))) {
                    ForEach($draft.phones) { $p in
                        TextField("TEL: 000-0000-0000", text: $p.number)
                            .keyboardType(.phonePad)
                    }
                    .onDelete { draft.phones.remove(atOffsets: $0) }

                    Button(L10n.t(.addPhone, lang: settings.language)) {
                        draft.phones.append(LabeledNumber(label: .unknown, number: ""))
                    }
                }

                Section(header: Text(L10n.t(.email, lang: settings.language))) {
                    TextField("example@mail.com", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(header: Text(L10n.t(.address, lang: settings.language))) {
                    TextEditor(text: $draft.address)
                        .frame(minHeight: 90)
                }

                Section {
                    Button(role: .destructive) {
                        draft = BusinessCard()
                    } label: {
                        Label(L10n.t(.clearAll, lang: settings.language), systemImage: "trash")
                    }
                }
            }
            .onAppear { draft = card }
            .navigationTitle(L10n.t(.edit, lang: settings.language))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.t(.cancel, lang: settings.language)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.t(.save, lang: settings.language)) {
                        card = draft
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
