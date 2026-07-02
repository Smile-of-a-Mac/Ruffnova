// DesignTokens — Multi-platform design system.
// Material hierarchy creates depth. Whitespace creates structure.
// Never fake glass — always use native system materials.

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
    static let circle: CGFloat = 999
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

// MARK: - Compatibility Aliases

typealias GlassSpacing = NativeSpacing
typealias GlassRadius = NativeRadius

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

// MARK: - Glass Card Modifier
// Lightweight floating card with ultra-thin material.
// Used sparingly — only for truly independent floating content.

struct NativeCardModifier: ViewModifier {
    var cornerRadius: CGFloat = NativeRadius.lg
    var material: Material = GlassMaterial.ultraLight

    func body(content: Content) -> some View {
        content
    }
}

struct LiquidGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var material: Material = GlassMaterial.ultraLight

    func body(content: Content) -> some View {
        content
            .background(material, in: shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func nativeCard(cornerRadius: CGFloat = NativeRadius.lg, material: Material = GlassMaterial.ultraLight) -> some View {
        modifier(NativeCardModifier(cornerRadius: cornerRadius, material: material))
    }

    /// Compatibility wrapper for existing `.glassCard()` call sites.
    func glassCard(cornerRadius: CGFloat = NativeRadius.lg, interactive: Bool = false) -> some View {
        self.nativeCard(cornerRadius: cornerRadius)
    }

    /// Floating glass circle — for toolbar buttons
    func glassCircle(size: CGFloat = 36, material: Material = GlassMaterial.ultraLight) -> some View {
        self
            .frame(width: size, height: size)
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

    func liquidGlassCapsule(material: Material = GlassMaterial.ultraLight) -> some View {
        modifier(LiquidGlassModifier(shape: Capsule(), material: material))
    }

    func toolbarGlassCapsule(material: Material = GlassMaterial.ultraLight) -> some View {
        self
            .background(material, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.separator.opacity(0.45), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    func toolbarGlassCircle(size: CGFloat = 36, material: Material = GlassMaterial.ultraLight) -> some View {
        self
            .frame(width: size, height: size)
    }

    func liquidGlassRounded(cornerRadius: CGFloat = NativeRadius.lg, material: Material = GlassMaterial.ultraLight) -> some View {
        modifier(LiquidGlassModifier(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            material: material
        ))
    }
}
