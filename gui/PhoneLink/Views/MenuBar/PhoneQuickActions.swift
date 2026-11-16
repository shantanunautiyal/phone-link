import AppKit
import PhoneLinkKit
import SwiftUI

/// The phone's quick actions as a grid of tiles: Do Not Disturb, Ringer, Hotspot, Find Phone, Send
/// Files and Phone Screen, each only while the phone offers it. Used by the menu bar popover and by
/// the sidebar's kebab-menu floating panel.
struct PhoneQuickActionsGrid: View {
    @Environment(DeviceStatusModel.self) private var deviceStatus
    @Environment(HotspotModel.self) private var hotspot
    @Environment(FileTransferModel.self) private var files
    @Environment(ScreenMirroringModel.self) private var mirroring
    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        let actions = self.actions
        if !actions.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(actions) { action in
                    QuickActionButton(action: action) { perform(action.kind) }
                }
            }
        }
    }

    private var actions: [QuickAction] {
        var actions: [QuickAction] = []
        if let tile = deviceStatus.doNotDisturbTile {
            actions.append(.init(kind: .doNotDisturb, title: tile.title, symbol: tile.symbol, state: tile.state, isOn: tile.isOn, isEnabled: tile.isEnabled))
        }
        if let tile = deviceStatus.ringerTile {
            actions.append(.init(kind: .ringer, title: tile.title, symbol: tile.symbol, state: tile.state, isOn: false, isEnabled: tile.isEnabled))
        }
        if let tile = hotspot.tile {
            actions.append(.init(kind: .hotspot, title: tile.title, symbol: tile.symbol, state: tile.state, isOn: tile.isOn, isEnabled: tile.isEnabled))
        }
        if let tile = deviceStatus.findPhoneTile {
            actions.append(.init(kind: .findPhone, title: tile.title, symbol: tile.symbol, state: tile.state, isOn: tile.isOn, isEnabled: tile.isEnabled))
        }
        if files.canSend {
            actions.append(.init(kind: .sendFiles, title: String(localized: "Send Files"), symbol: "arrow.up.doc", state: nil, isOn: false, isEnabled: true))
        }
        if mirroring.isOffered {
            actions.append(.init(kind: .phoneScreen, title: String(localized: "Phone Screen"), symbol: "apps.iphone", state: nil, isOn: false, isEnabled: true))
        }
        return actions
    }

    private func perform(_ kind: QuickAction.Kind) {
        switch kind {
        case .doNotDisturb: deviceStatus.toggleDoNotDisturb()
        case .ringer: deviceStatus.cycleRingerMode()
        case .findPhone: deviceStatus.findPhone()
        case .hotspot: hotspot.toggle()
        case .sendFiles: navigator.showSendFiles()
        case .phoneScreen:
            NSApp.activate()
            mirroring.openPhoneScreen()
        }
    }
}

/// One quick-action tile.
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
