import SwiftUI

/// Liquid Glass helpers.
///
/// macOS 26 adds `.glassEffect`, which anchors a glass shape *behind the view it is applied to* and
/// draws the view's content over it. Because of that, the effect belongs on the content view, never
/// on a bare `Shape` (a shape used as a view paints its default foreground — black — making the
/// surface look opaque). Before macOS 26 each surface used a stacked material; these helpers pick the
/// glass or the legacy stack per the running OS.

// MARK: - `.background(material, in: shape)` surfaces

extension View {
    /// A card-sized surface: Liquid Glass on macOS 26, else `material` clipped to `shape`.
    @ViewBuilder
    func glassCard(material: Material, in shape: some InsettableShape) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(material, in: shape)
        }
    }

    /// A card-sized surface: Liquid Glass on macOS 26, else `fill` (any shape style) clipped to `shape`.
    @ViewBuilder
    func glassCard<F: ShapeStyle, S: InsettableShape>(fill: F, in shape: S) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(fill, in: shape)
        }
    }
}

// MARK: - Layered material panels (capsule / rounded rect)

/// Applies Liquid Glass to the content on macOS 26; before it, the legacy ultra-thin material over
/// the scheme's tint, clipped to the shape.
private struct GlassPanelModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tintDark: Color
    let tintLight: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(colorScheme == .dark ? tintDark : tintLight)
                    }
                }
                .clipShape(shape)
        }
    }
}

extension View {
    /// Turns the view into a glass panel on macOS 26 (a capsule / rounded-rectangle surface); on
    /// older macOS it keeps the legacy material + tint stack, clipped to `shape`.
    func glassPanel<S: InsettableShape>(_ shape: S, tintDark: Color = .clear, tintLight: Color = .clear) -> some View {
        modifier(GlassPanelModifier(shape: shape, tintDark: tintDark, tintLight: tintLight))
    }
}
