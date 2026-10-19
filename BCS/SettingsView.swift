import SwiftUI
#if DEBUG
import PhotosUI
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    #if DEBUG
    @Environment(CardStore.self) private var store
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoDraft = BusinessCard()
    @State private var showPhotoDraftEditor = false
    @State private var fixtureSource: CardFixture.Source = .paper
    @State private var fixtureExport: FixtureExport?
    @State private var devMessage: String?
    @State private var isRecognizing = false
    
    private struct FixtureExport: Identifiable {
        let id = UUID()
        let url: URL
    }
    #endif
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.t(.language, lang: settings.language))) {
                    Picker("", selection: $settings.language) {
                        Text(L10n.t(.system, lang: settings.language)).tag(AppSettings.Language.system)
                        Text(L10n.t(.japanese, lang: settings.language)).tag(AppSettings.Language.japanese)
                        Text(L10n.t(.english, lang: settings.language)).tag(AppSettings.Language.english)
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }
                
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle(L10n.t(.settingsTitle, lang: settings.language))
            #if DEBUG
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task { await recognizePhoto(item) }
            }
            .sheet(isPresented: $showPhotoDraftEditor) {
                EditCardView(card: $photoDraft, onSave: { store.append($0) })
            }
            .sheet(item: $fixtureExport) { item in
                ShareSheet(items: [item.url])
            }
            #endif
        }
    }
    
    #if DEBUG
    // MARK: - Developer tools (DEBUG builds only)
    
    private var developerSection: some View {
        Section {
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Label(isRecognizing ? "認識中…" : "写真から OCR してパース", systemImage: "photo")
            }
            .disabled(isRecognizing)
            
            Picker("フィクスチャの由来", selection: $fixtureSource) {
                ForEach(CardFixture.Source.allCases.filter { $0 != .synthetic }) { source in
                    Text(sourceLabel(source)).tag(source)
                }
            }
            
            Button {
                exportFixture()
            } label: {
                Label("直近のスキャンをフィクスチャとして書き出す", systemImage: "square.and.arrow.up")
            }
            .disabled(!FixtureRecorder.shared.hasRecord)
            
            if let devMessage {
                Text(devMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Text("タイムゾーン DB: ZIP \(TimeZoneLookupTable.bundledZip.entryCount) 件 / 市外局番 \(TimeZoneLookupTable.bundledAreaCode.entryCount) 件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("開発用（DEBUG ビルドのみ）")
        } footer: {
            Text("書き出した JSON を BCSTests/Fixtures/ に置き、expected の間違っている項目だけ正しい値に直してください。名刺画像は保存されません。")
        }
    }
    
    private func sourceLabel(_ source: CardFixture.Source) -> String {
        switch source {
        case .paper:     return "紙の名刺をカメラで撮影"
        case .screen:    return "画面に表示した名刺を撮影"
        case .image:     return "画像ファイルから OCR"
        case .synthetic: return "手書き"
        }
    }
    
    private func recognizePhoto(_ item: PhotosPickerItem) async {
        isRecognizing = true
        defer {
            isRecognizing = false
            pickedPhoto = nil
        }
        
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let cg = image.cgImage else {
            devMessage = "画像を読み込めませんでした"
            return
        }
        
        let items = await TextRecognizer.recognize(cgImage: cg, orientation: Self.cgOrientation(image.imageOrientation))
        let card = CardParser().parse(items: items)
        FixtureRecorder.shared.record(items: items, card: card)
        
        guard !items.isEmpty else {
            devMessage = "テキストが検出されませんでした"
            return
        }
        devMessage = "\(items.count) 個のテキスト断片を認識しました"
        photoDraft = card
        showPhotoDraftEditor = true
    }
    
    /// Photos from the library carry EXIF orientation that `cgImage` ignores; Vision needs it.
    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
    
    private func exportFixture() {
        guard let fixture = FixtureRecorder.shared.makeFixture(source: fixtureSource) else { return }
        do {
            let data = try CardFixture.encode(fixture)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fixture.name).json")
            try data.write(to: url, options: .atomic)
            fixtureExport = FixtureExport(url: url)
            devMessage = "\(fixture.name).json を書き出しました"
        } catch {
            devMessage = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }
    #endif
}
