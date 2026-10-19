#if DEBUG
import Foundation
import CoreGraphics

/// Launch-argument hooks for screenshots and manual checks on the simulator (DEBUG builds only).
/// `-showScanResultSample` opens the scan result screen with a sample card right after launch.
enum DebugLaunch {
    /// `-fakeDocumentCamera`: replace VisionKit's camera (unavailable on the simulator) with a stand-in
    /// that renders a sample card image and hands it to the same capture path.
    static var usesFakeDocumentCamera: Bool {
        ProcessInfo.processInfo.arguments.contains("-fakeDocumentCamera")
    }
    
    /// `-uiTestTemporaryStore`: keep cards in a fresh temporary directory so UI tests start empty.
    static var usesTemporaryStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestTemporaryStore")
    }
    
    static var showsScanResultSample: Bool {
        ProcessInfo.processInfo.arguments.contains("-showScanResultSample")
    }
    
    /// `-showScanResultMissingCompany`: same screen with a card whose company cannot be read (review banner shown).
    static var showsScanResultMissingCompany: Bool {
        ProcessInfo.processInfo.arguments.contains("-showScanResultMissingCompany")
    }
    
    /// A card without a company line or e-mail, so the company stays empty and is flagged.
    static let missingCompanyItems: [OCRItem] = sampleItems.filter {
        !["NORTHWIND", "TEST SYSTEMS", "David.Morgan@Northwind.com"].contains($0.text)
    }
    
    /// OCR fragments of a typical two-column US card.
    static let sampleItems: [OCRItem] = [
        OCRItem(text: "NORTHWIND",                   box: CGRect(x: 0.064, y: 0.712, width: 0.648, height: 0.203)),
        OCRItem(text: "TEST SYSTEMS",                box: CGRect(x: 0.493, y: 0.655, width: 0.207, height: 0.048)),
        OCRItem(text: "D 407-555.0173",              box: CGRect(x: 0.507, y: 0.473, width: 0.194, height: 0.048)),
        OCRItem(text: "DAVID MORGAN",               box: CGRect(x: 0.049, y: 0.457, width: 0.316, height: 0.065)),
        OCRItem(text: "O 407.555.0162",              box: CGRect(x: 0.534, y: 0.408, width: 0.169, height: 0.053)),
        OCRItem(text: "David.Morgan@Northwind.com", box: CGRect(x: 0.507, y: 0.342, width: 0.400, height: 0.058)),
        OCRItem(text: "APPLICATIONS ENGINEER",       box: CGRect(x: 0.046, y: 0.312, width: 0.288, height: 0.048)),
        OCRItem(text: "12889 Lakeside Drive",       box: CGRect(x: 0.502, y: 0.248, width: 0.281, height: 0.061)),
        OCRItem(text: "Orlando, FL 32826",           box: CGRect(x: 0.506, y: 0.179, width: 0.235, height: 0.061)),
    ]
}
#endif
