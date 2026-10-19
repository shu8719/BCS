import SwiftUI
import PhotosUI
import UIKit

/// Loads a picked photo and runs the same OCR as the camera path.
enum PhotoImport {
    /// nil when the image could not be loaded; an empty array when no text was found.
    static func recognize(_ item: PhotosPickerItem) async -> [OCRItem]? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let cg = image.cgImage else { return nil }
        return await TextRecognizer.recognize(cgImage: cg, orientation: cgOrientation(image.imageOrientation))
    }
    
    /// Photos carry EXIF orientation that `cgImage` ignores; Vision needs it.
    static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
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
}
