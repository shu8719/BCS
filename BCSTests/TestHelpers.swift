import Foundation
import CoreGraphics
@testable import BCS

/// Builds an OCR line with a Vision-style normalized box (origin bottom-left, y grows upward).
func ocrLine(_ text: String, y: CGFloat, height: CGFloat = 0.03, x: CGFloat = 0.05, width: CGFloat = 0.5) -> OCRLine {
    OCRLine(text: text, box: CGRect(x: x, y: y, width: width, height: height))
}

/// Builds a raw OCR item (pre line-reconstruction) with the same box convention as `ocrLine`.
func ocrItem(_ text: String, y: CGFloat, height: CGFloat = 0.03, x: CGFloat = 0.05, width: CGFloat = 0.5) -> OCRItem {
    OCRItem(text: text, box: CGRect(x: x, y: y, width: width, height: height))
}

/// The CSVs shipped in the app bundle, loaded from the repo so tests do not depend on Bundle.main.
func repoTimeZoneDatabases() -> (zip: TimeZoneLookupTable, area: TimeZoneLookupTable) {
    // resolvingSymlinksInPath keeps this working when the test sources are symlinked elsewhere.
    let bcs = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("BCS").appendingPathComponent("TimeZone")
    return (TimeZoneLookupTable.zip(fileURL: bcs.appendingPathComponent("uszips.csv")),
            TimeZoneLookupTable.areaCode(fileURL: bcs.appendingPathComponent("ac-tz.csv")))
}

func repoTimeZoneResolver() -> TimeZoneResolver {
    let db = repoTimeZoneDatabases()
    return TimeZoneResolver(zipDB: db.zip, areaDB: db.area)
}

/// A small, well-formed US card used by several tests.
func sampleUSCardItems() -> [OCRItem] {
    [
        ocrItem("ACME Electronics Inc.",                    y: 0.85, height: 0.05),
        ocrItem("John Smith",                               y: 0.70, height: 0.06),
        ocrItem("Sales Manager",                            y: 0.62),
        ocrItem("Tel: 408-555-1234",                        y: 0.40),
        ocrItem("john.smith@acme.com",                      y: 0.32),
        ocrItem("123 Webster Avenue, San Jose, CA 95110",   y: 0.20),
    ]
}
