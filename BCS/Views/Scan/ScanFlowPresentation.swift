import SwiftUI
import PhotosUI

/// Presents the camera, the photo picker, the processing overlay, the result screen and the
/// error alert for a `ScanFlow`, so every screen that can start a scan shares one implementation.
struct ScanFlowPresentation: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store
    @Bindable var flow: ScanFlow
    @State private var pickedPhoto: PhotosPickerItem?
    
    private var lang: AppSettings.Language { settings.language }
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if flow.stage == .processing {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView().tint(.white).scaleEffect(1.5)
                    }
                }
            }
            .sheet(isPresented: Binding(get: { flow.stage == .camera },
                                        set: { if !$0, flow.stage == .camera { flow.cancel() } })) {
                ScannerView(
                    onRecognized: { items in flow.handleRecognized(items: items) },
                    onFailed: { flow.handleFailed() },
                    onStartProcessing: { flow.beginProcessing() }
                )
            }
            .photosPicker(isPresented: Binding(get: { flow.stage == .photoPicker },
                                               set: { if !$0, flow.stage == .photoPicker { flow.cancel() } }),
                          selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                pickedPhoto = nil
                flow.beginProcessing()
                Task {
                    if let items = await PhotoImport.recognize(item) {
                        flow.handleRecognized(items: items)
                    } else {
                        flow.handleFailed()
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { flow.isShowingResult },
                                                  set: { if !$0, flow.isShowingResult { flow.cancel() } })) {
                if let card = flow.resultCard {
                    ScanResultView(
                        card: card,
                        onChange: { flow.updateResult($0) },
                        onSave: { flow.save(into: store) },
                        onRetake: { flow.retake() },
                        onCancel: { flow.cancel() }
                    )
                }
            }
            .alert(
                Text(flow.error == .failed ? L10n.t(.scanFailedTitle, lang: lang) : L10n.t(.scanEmptyTitle, lang: lang)),
                isPresented: Binding(get: { flow.error != nil }, set: { if !$0 { flow.error = nil } }),
                presenting: flow.error
            ) { _ in
                Button(L10n.t(.ok, lang: lang), role: .cancel) {}
            } message: { error in
                Text(error == .failed ? L10n.t(.scanFailedMessage, lang: lang) : L10n.t(.scanEmptyMessage, lang: lang))
            }
    }
}

extension View {
    func scanFlowPresentation(_ flow: ScanFlow) -> some View {
        modifier(ScanFlowPresentation(flow: flow))
    }
}
