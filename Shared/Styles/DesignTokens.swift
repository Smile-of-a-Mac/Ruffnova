// DesignTokens — Shared spacing, radius, motion, and native material helpers.
// Material hierarchy creates depth. Whitespace creates structure.
// Never fake glass — prefer the system Liquid Glass API and semantic materials.

import SwiftUI

// MARK: - Spacing System (8pt grid)

enum NativeSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    #if os(iOS)
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    #else
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    #endif
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let section: CGFloat = 40
}

// MARK: - Corner Radius

enum NativeRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - Glass Material Hierarchy
// Window Glass → Sidebar Glass → Toolbar Glass → Floating Controls → Content → HUD
// Higher hierarchy = thinner material (more transparent)

enum GlassMaterial {
    /// Floating controls, buttons, pills — highest visual layer above content
    static var ultraLight: Material { .ultraThinMaterial }
    /// Search bars, floating panels, control bar
    static var light: Material { .thinMaterial }
    /// Content area background, sidebar
    static var content: Material { .regularMaterial }
    /// Informational overlays — rare use
    static var heavy: Material { .thickMaterial }
}

// MARK: - Animation Tokens
// Physical, subtle, purposeful — never exaggerated.

extension Animation {
    /// Standard spring for general state changes
    static let glassSpring = Animation.spring(response: 0.3, dampingFraction: 0.85)
    /// Quick spring for press/hover feedback
    static let glassPress = Animation.spring(response: 0.15, dampingFraction: 0.8)
    /// Smooth ease for opacity/fade transitions
    static let glassSmooth = Animation.easeInOut(duration: 0.2)
    /// Snappy spring for expand/collapse
    static let glassSnap = Animation.spring(response: 0.25, dampingFraction: 0.78)
    /// Gentle spring for floating element appearance
    static let glassFloat = Animation.spring(response: 0.4, dampingFraction: 0.82)
    /// Slower, steadier motion for stage fullscreen transitions.
    static let stageFullscreen = Animation.spring(response: 0.46, dampingFraction: 0.9, blendDuration: 0.08)
}

// MARK: - Native Glass

/// Applies the system Liquid Glass effect on macOS 26 / iOS 26 and falls back to a
/// native material on earlier systems. Reduce Transparency swaps the material for an
/// opaque background so content stays legible.
private struct NativeGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    let material: Material

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else if reduceTransparency {
            content.background(.background, in: shape)
        } else {
            content.background(material, in: shape)
        }
    }
}

extension View {
    func nativeLiquidGlass<S: InsettableShape>(
        in shape: S,
        material: Material = GlassMaterial.ultraLight
    ) -> some View {
        modifier(NativeGlassModifier(shape: shape, material: material))
    }

    func liquidGlassCapsule(material: Material = GlassMaterial.ultraLight) -> some View {
        nativeLiquidGlass(in: Capsule(), material: material)
    }

    func liquidGlassRounded(
        cornerRadius: CGFloat = NativeRadius.lg,
        material: Material = GlassMaterial.ultraLight
    ) -> some View {
        nativeLiquidGlass(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            material: material
        )
    }

    /// Content should inherit the window material instead of painting an opaque surface.
    func glassWindowBase() -> some View {
        #if os(macOS)
        return self
            .background(Color(nsColor: .windowBackgroundColor))
            .scrollContentBackground(.hidden)
        #else
        return self
            .background(Color(.systemBackground))
            .scrollContentBackground(.hidden)
        #endif
    }
}
