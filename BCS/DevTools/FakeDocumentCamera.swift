#if DEBUG
import UIKit

/// Stand-in for VNDocumentCameraViewController on the simulator (DEBUG, `-fakeDocumentCamera`).
/// Tapping 撮影 renders a sample card and passes it to the same capture handler as the real camera.
/// Captures alternate between a complete card and one without a company line.
final class FakeDocumentCameraController: UIViewController {
    private static var captureCount = 0
    private let onCapture: (UIImage, UIViewController) -> Void
    
    init(onCapture: @escaping (UIImage, UIViewController) -> Void) {
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let shutter = UIButton(type: .system)
        shutter.setTitle("撮影", for: .normal)
        shutter.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        shutter.accessibilityIdentifier = "fakeShutter"
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.addAction(UIAction { [weak self] _ in self?.capture() }, for: .touchUpInside)
        view.addSubview(shutter)
        NSLayoutConstraint.activate([
            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    private func capture() {
        let lines = Self.captureCount % 2 == 0 ? Self.completeCard : Self.cardWithoutCompany
        Self.captureCount += 1
        onCapture(Self.render(lines), self)
    }
    
    private typealias Line = (text: String, size: CGFloat, x: CGFloat, y: CGFloat)
    
    private static let completeCard: [Line] = [
        ("NORTHWIND", 96, 70, 60),
        ("DAVID MORGAN", 44, 60, 300), ("APPLICATIONS ENGINEER", 28, 60, 400),
        ("D 407-555.0173", 34, 620, 290), ("O 407.555.0162", 34, 620, 340),
        ("David.Morgan@Northwind.com", 34, 620, 390),
        ("12889 Lakeside Drive", 34, 620, 460), ("Orlando, FL 32826", 34, 620, 510),
    ]
    
    private static let cardWithoutCompany: [Line] = [
        ("HANAKO SATO", 44, 60, 300), ("RESEARCH SCIENTIST", 28, 60, 400),
        ("C 503-555-0187", 34, 620, 290),
        ("1120 NW Couch St", 34, 620, 460), ("Portland, OR 97209", 34, 620, 510),
    ]
    
    private static func render(_ lines: [Line]) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 660), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 660))
            for line in lines {
                (line.text as NSString).draw(at: CGPoint(x: line.x, y: line.y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: line.size, weight: .medium),
                    .foregroundColor: UIColor.black,
                ])
            }
        }
    }
}
#endif
