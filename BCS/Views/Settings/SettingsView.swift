import SwiftUI

/// 07 設定: language segmented control, data actions, and (DEBUG) developer tools.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store
    
    @State private var exportItem: ExportItem?
    @State private var confirmDeleteAll = false
    
    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    #if DEBUG
    @State private var fixtureExport: ExportItem?
    @State private var devMessage: String?
    #endif
    
    private var lang: AppSettings.Language { settings.language }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                Text(L10n.t(.settingsTitle, lang: lang))
                    .textStyle(.headlineMedium)
                    .foregroundStyle(M3.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle(L10n.t(.sectionDisplay, lang: lang))
                        languageGroup
                        sectionTitle(L10n.t(.sectionData, lang: lang))
                        dataGroup
                        #if DEBUG
                        sectionTitle(L10n.t(.sectionDeveloper, lang: lang))
                        developerGroup
                        developerFooter
                        #endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
            }
        }
        .background(M3.surfaceContainerLow.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let state = store.undoState {
                UndoBar(operation: state.operation) { store.restoreUndo() }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.undoState != nil)
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
                .onDisappear { try? FileManager.default.removeItem(at: item.url) }
        }
        .confirmationDialog(L10n.t(.resetAllTitle, lang: lang), isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button(L10n.t(.resetAction, lang: lang), role: .destructive) { store.resetAll() }
            Button(L10n.t(.cancel, lang: lang), role: .cancel) {}
        } message: {
            Text(L10n.t(.resetAllMessage, lang: lang))
        }
        #if DEBUG
        .sheet(item: $fixtureExport) { item in
            ShareSheet(items: [item.url])
        }
        #endif
    }
    
    // MARK: - Sections
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .textStyle(.titleSmall)
            .foregroundStyle(M3.primary)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .padding(.horizontal, 4)
    }
    
    private var languageGroup: some View {
        GroupedRows(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    IconView(.translate, size: 24, color: M3.onSurfaceVariant)
                    Text(L10n.t(.language, lang: lang))
                        .textStyle(.bodyLarge)
                        .foregroundStyle(M3.onSurface)
                }
                // Short, language-independent labels so three equal-width segments never truncate.
                SegmentedButton(
                    options: [
                        (AppSettings.Language.system, L10n.t(.langAuto, lang: lang)),
                        (AppSettings.Language.japanese, "日本語"),
                        (AppSettings.Language.english, "English"),
                    ],
                    selection: $settings.language
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(M3.surfaceContainerLowest)
        }
    }
    
    private var dataGroup: some View {
        GroupedRows(cornerRadius: 20) {
            SettingsRow(icon: .download, title: L10n.t(.exportCSVTitle, lang: lang),
                        subtitle: L10n.t(.cardsCount, lang: lang, store.cards.count), chevron: true) {
                exportAll()
            }
            .disabled(store.cards.isEmpty)
            SettingsRow(icon: .delete, title: L10n.t(.deleteAllCards, lang: lang), titleColor: M3.error, iconColor: M3.error) {
                confirmDeleteAll = true
            }
            .disabled(store.cards.isEmpty)
        }
    }
    
    private func exportAll() {
        do {
            exportItem = ExportItem(url: try CSVExporter.writeTemporaryFile(cards: store.cards, lang: lang))
        } catch {
            print("CSV write error: \(error)")
        }
    }
    
    #if DEBUG
    // MARK: - Developer tools (DEBUG builds only)
    
    private var developerGroup: some View {
        GroupedRows(cornerRadius: 20) {
            SettingsRow(icon: .share, title: "直近のスキャンをフィクスチャとして書き出す") {
                exportFixture()
            }
            .disabled(!FixtureRecorder.shared.hasRecord)
        }
    }
    
    private var developerFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let devMessage {
                Text(devMessage)
            }
            Text("タイムゾーン DB：ZIP \(formatted(TimeZoneLookupTable.bundledZip.entryCount)) 件 / 市外局番 \(formatted(TimeZoneLookupTable.bundledAreaCode.entryCount)) 件")
            Text("書き出した JSON を BCSTests/Fixtures/ に置き、expected の誤っている項目だけ正しい値に直してください。名刺画像は保存されません。")
            Text("由来（source）はカメラなら paper、写真なら image が自動で入ります。画面に表示した名刺を撮った場合は JSON の source を screen に直してください。")
        }
        .textStyle(.bodySmall)
        .foregroundStyle(M3.onSurfaceVariant)
        .padding(4)
    }
    
    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func exportFixture() {
        guard let fixture = FixtureRecorder.shared.makeFixture() else { return }
        do {
            let data = try CardFixture.encode(fixture)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fixture.name).json")
            try data.write(to: url, options: .atomic)
            fixtureExport = ExportItem(url: url)
            devMessage = "\(fixture.name).json を書き出しました"
        } catch {
            devMessage = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }
    #endif
}

/// One tappable settings row: icon, title, optional subtitle, optional chevron.
private struct SettingsRow: View {
    let icon: BCSIcon
    let title: String
    var subtitle: String? = nil
    var titleColor: Color = M3.onSurface
    var iconColor: Color = M3.onSurfaceVariant
    var chevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                IconView(icon, size: 24, color: iconColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .textStyle(.bodyLarge)
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(M3.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if chevron {
                    IconView(.chevronRight, size: 24, color: M3.onSurfaceVariant)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(M3.surfaceContainerLowest)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
