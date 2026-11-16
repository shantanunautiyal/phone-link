import AppKit
import PhoneLinkEngine
import PhoneLinkKit
import SwiftUI

/// The menu bar extra's popover (AirSync's MenubarView style): a glass card with the phone's status,
/// its controls, the recent notifications, and the app's commands. It replaces the system menu SwiftUI
/// would draw, and it is hosted in a borderless panel (`MenuBarController`).
struct MenuBarPopoverView: View {
    @Environment(EngineController.self) private var controller
    @Environment(AppNavigator.self) private var navigator
    @Environment(DeviceStatusModel.self) private var deviceStatus
    @Environment(HotspotModel.self) private var hotspot
    @Environment(FileTransferModel.self) private var files
    @Environment(ScreenMirroringModel.self) private var mirroring
    @Environment(NotificationsModel.self) private var notifications
    @Environment(UpdateModel.self) private var updates

    /// The recent notifications to preview.
    private var recent: [PhoneNotification] {
        Array(notifications.notifications.prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            Divider()
            PhoneQuickActionsGrid()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            if !recent.isEmpty {
                recentList
                    .padding(.vertical, 8)
                Divider()
            }
            commands
                .padding(.vertical, 6)
        }
        .frame(width: 400)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: controller.phone != nil ? "iphone.gen3" : "iphone.slash")
                .font(.system(size: 22))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.quaternary.opacity(0.6), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.phone?.name ?? String(localized: "Phone Link"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let summary = deviceStatus.summary {
                HStack(spacing: 6) {
                    if let wifi = summary.wifi {
                        Image(systemName: wifi.symbol, variableValue: wifi.variableValue)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .help(wifi.label)
                    }
                    if let cellular = summary.cellular {
                        Image(systemName: cellular.symbol, variableValue: cellular.variableValue)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .help(cellular.label)
                    }
                    if let battery = summary.battery {
                        HStack(spacing: 3) {
                            Image(systemName: battery.symbol, variableValue: battery.variableValue)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            if let percent = summary.batteryPercent {
                                Text(verbatim: "\(percent)%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .help(battery.label)
                    }
                }
            }
        }
    }

    private var statusText: String {
        switch controller.phase {
        case .running:
            if controller.phoneUnlinked {
                return String(localized: "Phone Not Linked")
            }
            if controller.allFeaturesDisabled {
                return String(localized: "Link to Windows Turned Off")
            }
            return controller.connected ? String(localized: "Connected") : String(localized: "Not Connected")
        case .idle, .starting:
            return String(localized: "Connecting…")
        case .webSignIn, .signedOut, .selectingPhone, .accountRemoved:
            return String(localized: "Not Signed In")
        case .failed:
            return String(localized: "Couldn't Connect")
        }
    }

    // MARK: - Recent notifications

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notifications")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if notifications.badgeCount > 0 {
                    Button {
                        navigator.showWindow()
                        navigator.show(.notifications)
                    } label: {
                        Text("See All").font(.system(size: 11))
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.horizontal, 16)

            ForEach(recent, id: \.key) { notification in
                Button {
                    navigator.showWindow()
                    navigator.showNotification(notification.key)
                } label: {
                    HStack(spacing: 10) {
                        PhoneAppIcon(packageName: notification.packageName, size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(NotificationsModel.appName(of: notification))
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(NotificationsModel.preview(of: notification))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Commands

    private var commands: some View {
        VStack(alignment: .leading, spacing: 0) {
            command(icon: "macbook.and.iphone", title: String(localized: "Open Phone Link")) { navigator.showWindow() }
            if files.canSend {
                command(icon: "arrow.up.doc", title: String(localized: "Send Files…")) { navigator.showSendFiles() }
            }
            command(icon: "gearshape", title: String(localized: "Settings…")) { openSettings() }
            if updates.isEnabled {
                if let release = updates.offered {
                    command(icon: "arrow.down.circle.fill", title: String(localized: "Update to \(release.version.description)…")) { updates.showWindow() }
                } else {
                    command(icon: "arrow.triangle.2.circlepath", title: String(localized: "Check for Updates…")) { updates.checkNow() }
                }
            }
            command(icon: "info.circle", title: String(localized: "About Phone Link")) { AboutPanel.show() }
            command(icon: "power", title: String(localized: "Quit Phone Link")) { NSApp.terminate(nil) }
        }
    }

    private func command(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let appMenu = NSApp.mainMenu?.items.first?.submenu,
           let index = appMenu.items.firstIndex(where: { $0.keyEquivalent == "," }) {
            appMenu.performActionForItem(at: index)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

/// One quick-action tile of the popover.
private struct QuickAction: Identifiable {
    enum Kind {
        case doNotDisturb, ringer, hotspot, findPhone, sendFiles, phoneScreen
    }

    let kind: Kind
    let title: String
    let symbol: String
    let state: String?
    let isOn: Bool
    let isEnabled: Bool

    var id: Kind { kind }
}

private struct QuickActionButton: View {
    let action: QuickAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: action.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(action.isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .frame(width: 30, height: 30)
                    .background(action.isOn ? Color.accentColor : Color.primary.opacity(0.06), in: Circle())
                Text(action.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let state = action.state {
                    Text(state)
                        .font(.system(size: 9))
                        .foregroundStyle(action.isOn ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .help(action.state ?? action.title)
    }
}
