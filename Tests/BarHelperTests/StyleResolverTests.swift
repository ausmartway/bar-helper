import XCTest
import CoreGraphics
@testable import BarHelper

/// Tests for the pure styling geometry/appearance logic (REQ-C05/C20/C21).
final class StyleResolverTests: XCTestCase {

    func testMenuBarFrameIsTheStripAboveVisibleFrame() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        // visibleFrame sits below the 24pt menu bar.
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 876)
        let bar = StyleResolver.menuBarFrame(screenFrame: screen, visibleFrame: visible)
        XCTAssertEqual(bar.height, 24, accuracy: 0.001)
        XCTAssertEqual(bar.width, 1440, accuracy: 0.001)
        XCTAssertEqual(bar.maxY, screen.maxY, accuracy: 0.001)
    }

    func testHasMenuBarFalseWhenNoStrip() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertFalse(StyleResolver.hasMenuBar(screenFrame: screen, visibleFrame: screen))
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 876)
        XCTAssertTrue(StyleResolver.hasMenuBar(screenFrame: screen, visibleFrame: visible))
    }

    func testNeedsOverlayOnlyWhenSomethingEnabled() {
        // An appearance with every visual effect off needs no overlay.
        var blank = Appearance.default
        blank.tint = nil
        blank.hasBorder = false
        blank.hasShadow = false
        blank.backgroundRemoval = false
        blank.cornerRadius = 0
        blank.roundedScreenCorners = false
        XCTAssertFalse(StyleResolver.needsOverlay(blank))

        // The shipped default enables a drop shadow, so it does need an overlay.
        XCTAssertTrue(StyleResolver.needsOverlay(.default))

        var tinted = blank
        tinted.tint = RGBAColor(white: 0, alpha: 0.5)
        XCTAssertTrue(StyleResolver.needsOverlay(tinted))

        var bordered = blank
        bordered.hasBorder = true
        XCTAssertTrue(StyleResolver.needsOverlay(bordered))
    }

    func testAppearanceSelectionHonorsDarkOverride() {
        var profile = Profile.default
        XCTAssertEqual(StyleResolver.appearance(for: profile, isDark: true), profile.appearance)

        var dark = Appearance.default
        dark.tint = RGBAColor(white: 0, alpha: 1)
        profile.darkAppearance = dark
        XCTAssertEqual(StyleResolver.appearance(for: profile, isDark: true), dark)
        XCTAssertEqual(StyleResolver.appearance(for: profile, isDark: false), profile.appearance)
    }
}
