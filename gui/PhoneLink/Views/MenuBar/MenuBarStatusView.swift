import AppKit
import SwiftUI

/// The menu bar extra's icon: the app's original notification icon, without any count badge, drawn at
/// its real aspect inside the status item's button (18 pt tall, width from the image).
struct MenuBarStatusView: View {
    var body: some View {
        Image("MenuBarIcon")
            .resizable()
            .scaledToFit()
            .frame(width: Self.width, height: Self.height)
            .accessibilityLabel("Phone Link")
    }

    static let height: CGFloat = 18

    /// The asset's width at `height`, so it is never distorted or letterboxed.
    static var width: CGFloat {
        guard let image = NSImage(named: "MenuBarIcon") else { return 22 }
        let h = max(image.size.height, 1)
        return (height * image.size.width / h).rounded()
    }
}
