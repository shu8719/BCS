import Foundation
import CoreGraphics
import Vision

/// Runs Vision text recognition and returns trimmed fragments with their normalized boxes.
enum TextRecognizer {
    static func recognize(cgImage: CGImage,
                          orientation: CGImagePropertyOrientation = .up,
                          completion: @escaping ([OCRItem]) -> Void) {
        let request = VNRecognizeTextRequest { req, err in
            if let err = err {
                print("OCR error:", err)
                completion([])
                return
            }
            
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            var items: [OCRItem] = []
            
            for o in observations {
                guard let top = o.topCandidates(1).first else { continue }
                let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }
                items.append(OCRItem(text: text, box: o.boundingBox))
            }
            
            completion(items)
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        // Keep small second-line address text from being dropped by OCR.
        request.minimumTextHeight = 0.01
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("VNImageRequestHandler error:", error)
                completion([])
            }
        }
    }
    
    static func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async -> [OCRItem] {
        await withCheckedContinuation { continuation in
            recognize(cgImage: cgImage, orientation: orientation) { items in
                continuation.resume(returning: items)
            }
        }
    }
}
