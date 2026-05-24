import SwiftUI
import Vision
import VisionKit
import UIKit
import Foundation

struct ScannerView: UIViewControllerRepresentable {
    @Binding var card: BusinessCard
    var onFinish:          () -> Void = {}
    var onEmpty:           () -> Void = {}
    var onFailed:          () -> Void = {}
    var onStartProcessing: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

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

        private let phoneParser = PhoneParser()
        private let addressParser = AddressParser()
        private let nameParser = NameParser()

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
                self.recognizeText(from: image) { items in
                    let result = self.parse(items: items)
                    DispatchQueue.main.async {
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
        
        private func recognizeText(from image: UIImage, completion: @escaping ([OCRItem]) -> Void) {
            guard let cg = image.cgImage else {
                completion([])
                return
            }
            
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
            
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("VNImageRequestHandler error:", error)
                    completion([])
                }
            }
        }
        
        private func parse(items: [OCRItem]) -> BusinessCard {
            let lines = buildLines(from: items)
            let texts = lines.map(\.text)
            
            var result = BusinessCard()
            result.email = texts.compactMap(extractEmail).first ?? ""
            result.company = pickCompany(from: texts, email: result.email)
            
            let addressInfo = addressParser.pickAddressBlockInfo(from: lines)
            let addrExtract = phoneParser.extractPhonesFromAddressText(addressInfo.text)
            result.address = addrExtract.cleanAddress
            
            // Try a second-pass recovery for multi-line addresses.
            let recovered = addressParser.recoverAddress(from: lines)
            if !recovered.isEmpty {
                let recoveredClean = phoneParser.extractPhonesFromAddressText(recovered).cleanAddress
                if isBetterAddressCandidate(recoveredClean, than: result.address) {
                    result.address = recoveredClean
                }
            }
            
            let phonesFromLines = phoneParser.extractPhones(from: lines)
            let phonesFromAll = phoneParser.extractPhonesFromWholeText(lines: lines)
            result.phones = phoneParser.dedupePhones(phonesFromLines + addrExtract.phones + phonesFromAll)
            
            result.name = nameParser.pickName(
                from: lines,
                email: result.email,
                company: result.company,
                address: result.address,
                looksLikeAddressLine: addressParser.looksLikeAddressLine
            )
            nameParser.normalizeNameCompanyByEmailHints(&result, companyScore: companyScore)
            
            return result
        }
        
        private func buildLines(from items: [OCRItem]) -> [OCRLine] {
            let sorted = items.sorted {
                if abs($0.box.midY - $1.box.midY) > 0.01 {
                    return $0.box.midY > $1.box.midY
                }
                return $0.box.minX < $1.box.minX
            }
            
            var rows: [[OCRItem]] = []
            let yThreshold: CGFloat = 0.02
            
            for it in sorted {
                if let last = rows.last, let rep = last.first {
                    let dy = abs(rep.box.midY - it.box.midY)
                    if dy < yThreshold {
                        rows[rows.count - 1].append(it)
                    } else {
                        rows.append([it])
                    }
                } else {
                    rows.append([it])
                }
            }
            
            func isLikelyNewColumn(prev: OCRItem, next: OCRItem) -> Bool {
                let gap = next.box.minX - prev.box.maxX
                let base = max(prev.box.width, next.box.width)
                return gap > base * 1.2
            }
            
            var lines: [OCRLine] = []
            for row in rows {
                let r = row.sorted { $0.box.minX < $1.box.minX }
                var segments: [[OCRItem]] = []
                var current: [OCRItem] = []
                
                for it in r {
                    if current.isEmpty {
                        current = [it]
                        continue
                    }
                    let prev = current.last!
                    if isLikelyNewColumn(prev: prev, next: it) {
                        segments.append(current)
                        current = [it]
                    } else {
                        current.append(it)
                    }
                }
                if !current.isEmpty { segments.append(current) }
                
                for seg in segments {
                    let text = seg.map { $0.text }.joined(separator: " ")
                    let box = seg.map(\.box).reduce(seg[0].box) { $0.union($1) }
                    lines.append(OCRLine(text: normalizeSpace(text), box: box))
                }
            }
            
            return lines
        }
        
        private func extractEmail(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let re = try? NSRegularExpression(
                pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                options: [.caseInsensitive]
            )
            let ns = t as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let m = re?.firstMatch(in: t, range: range) else { return nil }
            return ns.substring(with: m.range)
        }
        
        private func pickCompany(from texts: [String], email: String) -> String {
            let pool = texts.filter { !isJunkForCompany($0) }
            let scored = pool.map { t -> (String, Int) in (t, companyScore(t)) }
            
            if let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 4 {
                return best.0
            }
            
            if !email.isEmpty { return companyFromEmail(email) }
            return ""
        }
        
        private func companyScore(_ s: String) -> Int {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = t.lowercased()
            
            if lower.contains("@") || lower.contains("http") || lower.contains("www") { return -100 }
            if containsContactKeyword(lower) { return -100 }
            if isJobTitleLine(lower) { return -60 }
            if addressParser.looksLikeAddressLine(t) { return -80 }
            if t.range(of: #"[A-Za-z\.\s]+,\s*[A-Z]{2}\s*\d{5}(?:-\d{4})?"#, options: .regularExpression) != nil {
                return -80
            }
            
            var score = 0
            if t.range(of: #"(Inc\.?|LLC|Ltd\.?|Corp\.?|GmbH|Kft\.?|Co\.?,?\s*Ltd\.?)"#,
                       options: [.regularExpression, .caseInsensitive]) != nil {
                score += 8
            }
            if (3...70).contains(t.count) { score += 2 }
            
            if isAllCapsLikeLogo(t) { score -= 2 }
            return score
        }
        
        private func isJunkForCompany(_ s: String) -> Bool {
            let l = s.lowercased()
            return l.contains("@") || l.contains("http") || l.contains("www") || containsContactKeyword(l)
        }
        
        private func companyFromEmail(_ email: String) -> String {
            guard let at = email.firstIndex(of: "@") else { return "" }
            let domain = String(email[email.index(after: at)...])
            let key = domain.split(separator: ".").first.map(String.init) ?? ""
            if key.isEmpty { return "" }
            return key.prefix(1).uppercased() + key.dropFirst()
        }
        
        private func isAllCapsLikeLogo(_ s: String) -> Bool {
            let letters = s.filter { $0.isLetter }
            guard letters.count >= 4 else { return false }
            let upper = letters.filter { String($0) == String($0).uppercased() }.count
            return Double(upper) / Double(letters.count) > 0.9
        }
        
        private func isBetterAddressCandidate(_ candidate: String, than current: String) -> Bool {
            let c = normalizeSpace(candidate)
            let cur = normalizeSpace(current)
            if c.isEmpty { return false }
            if cur.isEmpty { return true }
            if c == cur { return false }
            
            func score(_ s: String) -> Int {
                var sc = 0
                let segments = s.split(separator: "/").count
                sc += segments * 15
                
                if s.range(of: #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { sc += 20 }
                if s.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { sc += 12 }
                if s.contains(",") { sc += 8 }
                if s.range(of: #"^\d{1,5}\s+\p{L}{2,}"#, options: .regularExpression) != nil { sc += 10 }
                if s.range(of: #"\b(street|st\.?|road|rd\.?|avenue|ave\.?|drive|dr\.?|suite|ste\.?|building|bldg\.?)\b"#,
                           options: [.regularExpression, .caseInsensitive]) != nil { sc += 10 }
                sc += min(20, s.count / 10)
                
                return sc
            }
            
            return score(c) > score(cur)
        }
    }
}

