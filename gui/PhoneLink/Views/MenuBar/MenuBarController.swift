import AppKit
import PhoneLinkKit
import SwiftUI

/// The menu bar extra: a custom status item whose icon hosts a SwiftUI view, and a borderless glass
/// panel that opens under it (as AirSync's MenubarPanel) instead of the system menu. Clicking outside
/// closes it; the item hides with the app's "Show Phone Link in the menu bar" setting.
@MainActor
final class MenuBarController: NSObject {
    private let makeIcon: () -> NSHostingView<AnyView>
    private let makePanelContent: () -> NSHostingView<AnyView>

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?

    init(
        makeIcon: @escaping () -> NSHostingView<AnyView>,
        makePanelContent: @escaping () -> NSHostingView<AnyView>
    ) {
        self.makeIcon = makeIcon
        self.makePanelContent = makePanelContent
    }

    /// Creates the status item and starts listening to the menu-bar preference.
    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            let icon = makeIcon()
            icon.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ])
            button.action = #selector(toggle)
            button.target = self
        }
        updateVisibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    /// Removes the status item and its observers.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func defaultsChanged() {
        updateVisibility()
    }

    private func updateVisibility() {
        let shown = UserDefaults.standard.object(forKey: PreferenceKeys.showMenuBarExtra) as? Bool ?? true
        statusItem?.isVisible = shown
    }

    @objc private func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        guard let button = statusItem?.button else { return }

        if panel == nil {
            let content = makePanelContent()
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            content.autoresizingMask = [.width, .height]
            panel.contentView = content
            self.panel = panel
        }

        guard let panel else { return }
        let fitting = panel.contentView?.fittingSize ?? NSSize(width: 416, height: 520)
        panel.setContentSize(fitting)

        let buttonFrame = button.window?.frame ?? .zero
        let x = buttonFrame.midX - fitting.width / 2
        let y = buttonFrame.minY - fitting.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.orderFrontRegardless()
        installMonitors(button: button, panel: panel)
    }

    private func installMonitors(button: NSButton, panel: NSPanel) {
        removeMonitors()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hideIfOutside(event, button: button, panel: panel)
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hideIfOutside(event, button: button, panel: panel)
            return event
        }
    }

    private func hideIfOutside(_ event: NSEvent, button: NSButton, panel: NSPanel) {
        let location = NSEvent.mouseLocation
        guard !NSMouseInRect(location, panel.frame, false) else { return }
        if let buttonWindow = button.window, NSMouseInRect(location, buttonWindow.frame, false) {
            return
        }
        hide()
    }

    private func removeMonitors() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private func hide() {
        panel?.orderOut(nil)
        removeMonitors()
    }
}
