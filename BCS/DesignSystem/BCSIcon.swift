import SwiftUI

/// Icons exported from Figma (Material Icons 24px) as SVG image sets under Assets.xcassets/Icons.
/// All are template images except `brandMark`, `reviewBadge`, `guideFrame`, `shutter` and `shutterRing`.
enum BCSIcon: String, CaseIterable {
    case add = "icon-add"
    case arrowBack = "icon-arrow-back"
    case business = "icon-business"
    case call = "icon-call"
    case camera = "icon-camera"
    case check = "icon-check"
    case checklist = "icon-checklist"
    case chevronRight = "icon-chevron-right"
    case close = "icon-close"
    case code = "icon-code"
    case contacts = "icon-contacts"
    case copy = "icon-copy"
    case delete = "icon-delete"
    case download = "icon-download"
    case edit = "icon-edit"
    case expandMore = "icon-expand-more"
    case flash = "icon-flash"
    case image = "icon-image"
    case info = "icon-info"
    case location = "icon-location"
    case mail = "icon-mail"
    case moreVert = "icon-more-vert"
    case person = "icon-person"
    case removeCircle = "icon-remove-circle"
    case schedule = "icon-schedule"
    case search = "icon-search"
    case settings = "icon-settings"
    case share = "icon-share"
    case sort = "icon-sort"
    case sparkle = "icon-sparkle"
    case translate = "icon-translate"
    case warning = "icon-warning"
    // Multi-color artwork, rendered as-is.
    case brandMark = "icon-brand-mark"
    case reviewBadge = "icon-review-badge"
    case guideFrame = "icon-guide-frame"
    case shutter = "icon-shutter"
    case shutterRing = "icon-shutter-ring"
    
    var isTemplate: Bool {
        switch self {
        case .brandMark, .reviewBadge, .guideFrame, .shutter, .shutterRing: return false
        default: return true
        }
    }
}

/// Renders a `BCSIcon` at a square size, tinted when the icon is a template.
struct IconView: View {
    let icon: BCSIcon
    var size: CGFloat = 24
    var color: Color = M3.onSurfaceVariant
    
    init(_ icon: BCSIcon, size: CGFloat = 24, color: Color = M3.onSurfaceVariant) {
        self.icon = icon
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Image(icon.rawValue)
            .resizable()
            .renderingMode(icon.isTemplate ? .template : .original)
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}
