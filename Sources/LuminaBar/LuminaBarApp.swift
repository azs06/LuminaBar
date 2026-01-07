import SwiftUI
import AppKit

@main
struct LuminaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var colorPanelObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeColorPanel()

        Task {
            await YeelightManager.shared.discover()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Lumina")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 0)  // Height auto-sized
        popover.behavior = .transient  // Default: close on outside click
        popover.animates = true

        let hostingController = NSHostingController(rootView: PopoverView())
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
    }

    private func observeColorPanel() {
        // When color panel opens, switch to semitransient so popover stays open
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: NSColorPanel.shared,
            queue: .main
        ) { [weak self] _ in
            self?.popover.behavior = .semitransient
        }

        // When color panel closes, switch back to transient
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: NSColorPanel.shared,
            queue: .main
        ) { [weak self] _ in
            self?.popover.behavior = .transient
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
