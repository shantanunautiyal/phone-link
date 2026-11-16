import PhoneLinkKit
import SwiftUI

/// The menu bar extra's icon: a phone glyph, with the unread-notification count in a capsule while any
/// notification is in the list, and a phone that is not connected drawn slashed.
struct MenuBarStatusView: View {
    @Environment(EngineController.self) private var controller
    @Environment(NotificationsModel.self) private var notifications

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: controller.phone != nil ? "iphone.gen3" : "iphone.slash")
                .font(.system(size: 13, weight: .medium))
                .imageScale(.small)
            if notifications.badgeCount > 0 {
                Text(verbatim: "\(notifications.badgeCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }
}
