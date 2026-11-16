import SwiftUI

/// The animated value of a water-drop bounce: the icon squashes and stretches through a spring
/// keyframe sequence.
private struct WaterDropValue {
    var scale: CGFloat = 1
}

/// A bouncy water-drop bounce: when `isActive` turns true, the view springs through a squash-and-
/// stretch keyframe sequence. Applied to the tab icons of the center capsule; the animation replays
/// when a tab becomes selected.
struct WaterDropBounce: ViewModifier {
    let isActive: Bool
    @State private var fired = false

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(
                initialValue: WaterDropValue(),
                trigger: isActive ? fired : false
            ) { content, value in
                content.scaleEffect(value.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.25, duration: 0.14, spring: Spring(response: 0.30, dampingRatio: 0.50))
                    SpringKeyframe(0.94, duration: 0.20, spring: Spring(response: 0.28, dampingRatio: 0.45))
                    SpringKeyframe(1.0, duration: 0.26, spring: Spring(response: 0.30, dampingRatio: 0.50))
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue { fired.toggle() }
            }
    }
}

extension View {
    /// Replays a bouncy water-drop bounce when `isActive` becomes true.
    func waterDropBounce(isActive: Bool) -> some View {
        modifier(WaterDropBounce(isActive: isActive))
    }
}
