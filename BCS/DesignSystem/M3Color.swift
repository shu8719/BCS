import SwiftUI

/// Material 3 (Light) color tokens from the Figma design. Values live in Assets.xcassets/M3.
/// Dark mode is intentionally undefined; add a Dark appearance to each Color Set to support it.
enum M3 {
    static let primary                 = Color("primary")
    static let onPrimary               = Color("on-primary")
    static let primaryContainer        = Color("primary-container")
    static let onPrimaryContainer      = Color("on-primary-container")
    static let secondary               = Color("secondary")
    static let secondaryContainer      = Color("secondary-container")
    static let onSecondaryContainer    = Color("on-secondary-container")
    static let tertiaryContainer       = Color("tertiary-container")
    static let onTertiaryContainer     = Color("on-tertiary-container")
    static let error                   = Color("error")
    static let errorContainer          = Color("error-container")
    static let onErrorContainer        = Color("on-error-container")
    static let surface                 = Color("surface")
    static let surfaceContainerLowest  = Color("surface-container-lowest")
    static let surfaceContainerLow     = Color("surface-container-low")
    static let surfaceContainer        = Color("surface-container")
    static let surfaceContainerHigh    = Color("surface-container-high")
    static let surfaceContainerHighest = Color("surface-container-highest")
    static let onSurface               = Color("on-surface")
    static let onSurfaceVariant        = Color("on-surface-variant")
    static let outline                 = Color("outline")
    static let outlineVariant          = Color("outline-variant")
    static let warning                 = Color("warning")
    static let success                 = Color("success")
    static let successContainer        = Color("success-container")
    
    /// Chip background for a US time zone code ("EST" / "CST" / "MST" / "PST").
    static func tzContainer(_ code: String) -> Color {
        Color("tz-\(code.lowercased())-container")
    }
    
    static func tzOnContainer(_ code: String) -> Color {
        Color("tz-on-\(code.lowercased())-container")
    }
}
