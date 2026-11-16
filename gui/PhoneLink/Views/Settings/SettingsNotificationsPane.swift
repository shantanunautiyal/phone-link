import PhoneLinkKit
import SwiftUI
import UserNotifications

/// Notifications: whether the phone's notifications show on this Mac, how each app's do, and the
/// access the phone gives.
struct SettingsNotificationsPane: View {
    @Environment(SettingsModel.self) private var model
    @Environment(EngineController.self) private var controller

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                MacNotificationPermissionRow()
            } header: {
                Text("On This Mac")
            } footer: {
                Text("Phone Link shows the phone's notifications as macOS banners only when macOS allows the app to notify.")
            }
            if !model.isAvailable {
                SettingsUnavailableNote()
            }
            Section {
                Toggle("Show notifications from my phone", isOn: $model.showsPhoneNotifications)
                Toggle("Alert me when the phone's battery is low", isOn: $model.alertsLowBattery)
                Toggle("Pause apps that send too many notifications", isOn: $model.pausesNoisyApps)
                    .disabled(!model.showsPhoneNotifications)
            }
            .disabled(!model.isAvailable)
            if let state = model.notificationsState {
                // Per-app settings apply only while the phone reports its apps.
                if state.appListSupported {
                    Section {
                        ForEach(model.notificationApps) { app in
                            AppRow(app: app)
                        }
                    } header: {
                        Text("Apps")
                    } footer: {
                        Text("Apps appear here after they send a notification. Choosing Off for an app also stops your phone from sending its notifications.")
                    }
                    .disabled(!state.pcPermission)
                }
                if state.capable {
                    Section("On \(controller.phone?.name ?? String(localized: "Your Phone"))") {
                        if state.lowRamDevice && !state.devicePermission {
                            LabeledContent("Notification access", value: String(localized: "Not Supported"))
                        } else {
                            SettingsAccessRow(
                                title: "Notification access",
                                allowed: state.devicePermission,
                                pending: model.pendingRequests.contains(.notificationAccess)
                            ) {
                                Task { await model.requestNotificationAccess() }
                            }
                        }
                        if state.sensitivePromptOffered {
                            SettingsAccessRow(
                                title: "Sensitive content",
                                allowed: state.sensitivePermission,
                                pending: model.pendingRequests.contains(.sensitiveContent)
                            ) {
                                Task { await model.requestSensitiveContent() }
                            }
                        }
                    }
                }
            }
        }
        .settingsPaneForm()
        .onAppear {
            model.setNotificationsPaneVisible(true)
            model.reload()
        }
        .onDisappear { model.setNotificationsPaneVisible(false) }
        // Again once the engine starts while the pane is open.
        .task(id: model.isAvailable) { await model.notificationsPaneAppeared() }
    }
}

/// The Mac's permission for the app's notifications: what macOS reports, and a way to change it when a
/// notification is not allowed (the app's ad-hoc builds often are — the fix is signing with an Apple
/// Development identity from a free team).
private struct MacNotificationPermissionRow: View {
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        LabeledContent {
            switch status {
            case .none:
                Text("Checking…")
                    .foregroundStyle(.secondary)
            case .some(.authorized), .some(.provisional):
                Text("Allowed")
                    .foregroundStyle(.secondary)
            case .some(.notDetermined):
                Button("Allow Notifications") { requestAuthorization() }
            default:
                Button("Open System Settings") { openSystemSettings() }
            }
        } label: {
            Text("Notifications from Phone Link")
            if let status, !Self.allows(status) {
                Text(status == .notDetermined
                    ? "macOS hasn't been asked to allow Phone Link to notify yet."
                    : "macOS is blocking notifications for this app.")
            }
        }
        .task {
            status = await Self.readStatus()
        }
    }

    static func allows(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    static func readStatus() async -> UNAuthorizationStatus? {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in
                status = await Self.readStatus()
            }
        }
    }

    private func openSystemSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.nlog.PhoneLink"
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?bundleID=\(bundleID)")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}

/// An app's pop-up: how its notifications reach this Mac.
private struct AppRow: View {
    let app: SettingsNotificationApp
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Picker(selection: choice) {
            ForEach(SettingsNotificationChoice.allCases, id: \.self) { choice in
                Text(choice.title).tag(choice)
            }
        } label: {
            Text(app.name)
            if let muted = app.mutedText {
                Text(muted)
            }
        }
        .pickerStyle(.menu)
        .disabled(model.pendingApps.contains(app.packageName))
    }

    private var choice: Binding<SettingsNotificationChoice> {
        Binding(
            get: { app.choice },
            set: { choice in
                Task { await model.setChoice(choice, forApp: app.packageName) }
            }
        )
    }
}
