import SwiftUI
import VisionKit
import UIKit

struct ScannerView: UIViewControllerRepresentable {
    @Binding var card: BusinessCard
    var onFinish:          () -> Void = {}
    var onEmpty:           () -> Void = {}
    var onFailed:          () -> Void = {}
    var onStartProcessing: () -> Void = {}

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onFinish: onFinish, onEmpty: onEmpty, onFailed: onFailed, onStartProcessing: onStartProcessing)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: ScannerView
        private let onFinish:          () -> Void
        private let onEmpty:           () -> Void
        private let onFailed:          () -> Void
        private let onStartProcessing: () -> Void

        private let parser = CardParser()

        init(parent: ScannerView, onFinish: @escaping () -> Void, onEmpty: @escaping () -> Void,
             onFailed: @escaping () -> Void, onStartProcessing: @escaping () -> Void) {
            self.parent = parent
            self.onFinish          = onFinish
            self.onEmpty           = onEmpty
            self.onFailed          = onFailed
            self.onStartProcessing = onStartProcessing
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }
            
            let image = scan.imageOfPage(at: max(0, scan.pageCount - 1))
            controller.dismiss(animated: true) {
                self.onStartProcessing()
                guard let cg = image.cgImage else {
                    self.onEmpty()
                    return
                }
                TextRecognizer.recognize(cgImage: cg) { items in
                    let result = self.parser.parse(items: items)
                    DispatchQueue.main.async {
                        #if DEBUG
                        FixtureRecorder.shared.record(items: items, card: result)
                        #endif
                        let isEmpty = result.name.isEmpty && result.company.isEmpty &&
                                      result.email.isEmpty && result.phones.isEmpty &&
                                      result.address.isEmpty
                        if isEmpty {
                            self.onEmpty()
                        } else {
                            self.parent.card = result
                            self.onFinish()
                        }
                    }
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onFailed()
            }
        }
    }
}

