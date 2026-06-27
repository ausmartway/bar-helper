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

    /// SF Symbol name used for the section separators/chevrons (REQ-C19).
    var separatorIconSymbol: String
    /// Whether the divider/chevron icons are shown at all (REQ-C19).
    var showDividerIcons: Bool

    /// Round the screen's bottom-of-menu-bar corners (REQ-C21).
    var roundedScreenCorners: Bool
    /// Remove/black-out the wallpaper showing behind the menu bar (REQ-C21).
    var backgroundRemoval: Bool

    static var `default`: Appearance {
        Appearance(
            tint: nil,
            hasBorder: false,
            borderColor: RGBAColor(white: 0, alpha: 0.25),
            hasShadow: true,
            cornerRadius: 0,
            separatorIconSymbol: "chevron.left",
            showDividerIcons: true,
            roundedScreenCorners: false,
            backgroundRemoval: false
        )
    }

    // Memberwise init is synthesized and used by `Appearance.default`.
    init(tint: RGBAColor?, hasBorder: Bool, borderColor: RGBAColor, hasShadow: Bool,
         cornerRadius: Double, separatorIconSymbol: String, showDividerIcons: Bool,
         roundedScreenCorners: Bool, backgroundRemoval: Bool) {
        self.tint = tint
        self.hasBorder = hasBorder
        self.borderColor = borderColor
        self.hasShadow = hasShadow
        self.cornerRadius = cornerRadius
        self.separatorIconSymbol = separatorIconSymbol
        self.showDividerIcons = showDividerIcons
        self.roundedScreenCorners = roundedScreenCorners
        self.backgroundRemoval = backgroundRemoval
    }

    /// Back-compatible decoder: the styling fields added after v1 fall back to
    /// their defaults when an older payload omits them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Appearance.default
        tint = try c.decodeIfPresent(RGBAColor.self, forKey: .tint)
        hasBorder = try c.decodeIfPresent(Bool.self, forKey: .hasBorder) ?? d.hasBorder
        borderColor = try c.decodeIfPresent(RGBAColor.self, forKey: .borderColor) ?? d.borderColor
        hasShadow = try c.decodeIfPresent(Bool.self, forKey: .hasShadow) ?? d.hasShadow
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? d.cornerRadius
        separatorIconSymbol = try c.decodeIfPresent(String.self, forKey: .separatorIconSymbol) ?? d.separatorIconSymbol
        showDividerIcons = try c.decodeIfPresent(Bool.self, forKey: .showDividerIcons) ?? d.showDividerIcons
        roundedScreenCorners = try c.decodeIfPresent(Bool.self, forKey: .roundedScreenCorners) ?? d.roundedScreenCorners
        backgroundRemoval = try c.decodeIfPresent(Bool.self, forKey: .backgroundRemoval) ?? d.backgroundRemoval
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
