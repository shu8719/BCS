import CoreGraphics

/// One text fragment as returned by Vision, with its normalized bounding box
/// (origin bottom-left, 0...1 in both axes).
struct OCRItem {
    let text: String
    let box: CGRect
}

/// A reconstructed line: fragments on the same row and column joined with spaces.
/// Same shape as OCRItem, kept distinct so the parsers cannot be handed raw fragments by mistake.
struct OCRLine {
    let text: String
    let box: CGRect
}
