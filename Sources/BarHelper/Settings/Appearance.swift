import AppKit

/// Menu-bar styling options (REQ-C05): tint, border, shadow, and shape.
///
/// Colors are stored as Codable RGBA components so a profile is fully
/// serializable. `nsColor` bridges back to AppKit for rendering.
struct Appearance: Codable, Equatable {
    var tint: RGBAColor?
    var hasBorder: Bool
    var borderColor: RGBAColor
    var hasShadow: Bool
    /// Corner radius applied to the styled menu-bar region.
    var cornerRadius: Double

    static var `default`: Appearance {
        Appearance(
            tint: nil,
            hasBorder: false,
            borderColor: RGBAColor(white: 0, alpha: 0.25),
            hasShadow: true,
            cornerRadius: 0
        )
    }
}

/// A serializable color. Kept separate from AppKit so the model layer stays
/// portable and `Codable`.
struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(white: Double, alpha: Double) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
