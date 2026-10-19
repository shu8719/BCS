import SwiftUI
import VisionKit
import UIKit

/// Wraps VisionKit's document camera and hands the OCR fragments of the captured page to the caller.
/// Parsing happens in `ScanFlow`, not here.
struct ScannerView: UIViewControllerRepresentable {
    var onRecognized:      ([OCRItem]) -> Void = { _ in }
    var onFailed:          () -> Void = {}
    var onStartProcessing: () -> Void = {}

    func makeUIViewController(context: Context) -> UIViewController {
        #if DEBUG
        if DebugLaunch.usesFakeDocumentCamera {
            let coordinator = context.coordinator
            return FakeDocumentCameraController { image, controller in
                coordinator.handleCapture(image, from: controller)
            }
        }
        #endif
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized, onFailed: onFailed, onStartProcessing: onStartProcessing)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onRecognized:      ([OCRItem]) -> Void
        private let onFailed:          () -> Void
        private let onStartProcessing: () -> Void

        init(onRecognized: @escaping ([OCRItem]) -> Void, onFailed: @escaping () -> Void,
             onStartProcessing: @escaping () -> Void) {
            self.onRecognized      = onRecognized
            self.onFailed          = onFailed
            self.onStartProcessing = onStartProcessing
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }
            
            handleCapture(scan.imageOfPage(at: max(0, scan.pageCount - 1)), from: controller)
        }
        
        /// Shared by VisionKit and the DEBUG fake camera.
        func handleCapture(_ image: UIImage, from controller: UIViewController) {
            controller.dismiss(animated: true) {
                self.onStartProcessing()
                guard let cg = image.cgImage else {
                    self.onRecognized([])
                    return
                }
                TextRecognizer.recognize(cgImage: cg) { items in
                    DispatchQueue.main.async {
                        self.onRecognized(items)
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
