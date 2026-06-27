import CoreGraphics

/// Pure geometry/appearance helpers for the menu-bar styling overlay
/// (REQ-C05/C20/C21). Kept free of AppKit window code so it can be unit tested.
enum StyleResolver {

    /// The menu-bar strip rectangle for a screen, in the bottom-left origin
    /// coordinate space AppKit uses for windows. The menu bar occupies the gap
    /// between the top of the screen frame and the top of its visible frame.
    static func menuBarFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let height = max(0, screenFrame.maxY - visibleFrame.maxY)
        return CGRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - height,
            width: screenFrame.width,
            height: height
        )
    }

    /// Whether a screen has a meaningful menu bar to style (height > 0).
    static func hasMenuBar(screenFrame: CGRect, visibleFrame: CGRect) -> Bool {
        menuBarFrame(screenFrame: screenFrame, visibleFrame: visibleFrame).height > 1
    }

    /// Resolve which `Appearance` applies for the current interface style,
    /// honoring an optional dark-mode override (REQ-C20).
    static func appearance(for profile: Profile, isDark: Bool) -> Appearance {
        profile.appearance(forDarkMode: isDark)
    }

    /// Whether the overlay needs to draw anything at all for a given appearance.
    /// When nothing is enabled we can skip creating/showing the window.
    static func needsOverlay(_ appearance: Appearance) -> Bool {
        appearance.tint != nil
            || appearance.hasBorder
            || appearance.hasShadow
            || appearance.backgroundRemoval
            || appearance.cornerRadius > 0
            || appearance.roundedScreenCorners
    }
}
