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

struct CompatibleNavigationContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
        }
        #else
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
        }
        #endif
    }
}

struct CompatibleLabeledContent<Content: View>: View {
    private let label: String
    private let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    init(_ label: String, value: String) where Content == Text {
        self.init(label) { Text(value) }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: NativeSpacing.md) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: NativeSpacing.md)
            content
                .multilineTextAlignment(.trailing)
        }
    }
}

extension View {
    /// Uses the system Liquid Glass API when available, with the native material fallback.
    @ViewBuilder
    func nativeLiquidGlass<S: Shape>(in shape: S) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
        #else
        self.background(.regularMaterial, in: shape)
        #endif
    }

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
    @ViewBuilder
    func glassWindowBase() -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            self
                .background(Color(nsColor: .windowBackgroundColor))
                .scrollContentBackground(.hidden)
        } else {
            self.background(Color(nsColor: .windowBackgroundColor))
        }
        #else
        if #available(iOS 16.0, *) {
            self
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)
        } else {
            self.background(Color(.systemBackground))
        }
        #endif
    }

    @ViewBuilder
    func compatibleSidebarWidth() -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            self.navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func visibleScrollIndicators() -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            self.scrollIndicators(.visible)
        } else {
            self
        }
        #else
        if #available(iOS 16.0, *) {
            self.scrollIndicators(.visible)
        } else {
            self
        }
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
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.7)
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
