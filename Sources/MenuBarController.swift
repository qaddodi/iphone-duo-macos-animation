import Foundation
import AppKit
import SwiftUI

public final class MenuBarController: NSObject, NSWindowDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var controlPanelWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var angleMenuItem: NSMenuItem?
    private var presetRootItem: NSMenuItem?
    private var lastAngle: Double = 120.0
    private var lastIsConnected = false

    public override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Tiltglass")
            button.imagePosition = .imageLeading
            button.title = ""
        }

        statusItem = item
        rebuildMenu()
        refreshMenuBarTitle()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "Tiltglass", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let angle = NSMenuItem(title: "Lid Sensor: Initializing...", action: nil, keyEquivalent: "")
        angle.isEnabled = false
        angleMenuItem = angle
        menu.addItem(angle)

        menu.addItem(.separator())

        let presetItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetRootItem = presetItem
        menu.addItem(presetItem)
        rebuildPresetMenu()

        let openSettings = NSMenuItem(title: "Settings...", action: #selector(openControlPanel), keyEquivalent: ",")
        openSettings.target = self
        menu.addItem(openSettings)

        let welcome = NSMenuItem(title: "Welcome & Privacy...", action: #selector(openOnboardingWindow), keyEquivalent: "")
        welcome.target = self
        menu.addItem(welcome)

        let capture = NSMenuItem(title: "Refresh Screen Snapshot", action: #selector(recaptureScreen), keyEquivalent: "r")
        capture.target = self
        menu.addItem(capture)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Tiltglass", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    public func rebuildPresetMenu() {
        guard let root = presetRootItem else { return }

        let submenu = NSMenu()
        let settings = AppSettings.shared

        for preset in AppSettings.builtInPresets {
            let item = NSMenuItem(title: preset.name, action: #selector(applyPresetMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            item.state = settings.activePresetID == preset.id ? .on : .off
            submenu.addItem(item)
        }

        if !settings.userPresets.isEmpty {
            submenu.addItem(.separator())
            for preset in settings.userPresets {
                let item = NSMenuItem(title: preset.name, action: #selector(applyPresetMenuItem(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.id
                item.state = settings.activePresetID == preset.id ? .on : .off
                submenu.addItem(item)
            }
        }

        root.submenu = submenu
    }

    @objc private func applyPresetMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AppSettings.shared.applyPreset(id: id)
        rebuildPresetMenu()
    }

    public func updateAngleDisplay(angle: Double, isConnected: Bool) {
        lastAngle = angle
        lastIsConnected = isConnected

        if let button = statusItem?.button {
            button.title = AppSettings.shared.showAngleInMenuBar ? " \(Int(angle))°" : ""
        }

        if let angleMenuItem {
            if isConnected {
                let status = AppSettings.shared.isClosing ? "Closing" : "Ready"
                angleMenuItem.title = "Lid: \(status) \(Int(angle))°"
            } else {
                angleMenuItem.title = "Lid Sensor: Unavailable"
            }
        }
    }

    public func refreshMenuBarTitle() {
        guard let button = statusItem?.button else { return }
        button.title = AppSettings.shared.showAngleInMenuBar ? " \(Int(lastAngle))°" : ""
    }

    @objc public func openControlPanel() {
        if let window = controlPanelWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 690),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentViewController = NSHostingController(rootView: LiquidGlassControlPanel())
        window.isReleasedWhenClosed = false
        window.delegate = self

        controlPanelWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func openOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        let view = OnboardingView { [weak self, weak window] in
            window?.close()
            self?.openControlPanel()
        }

        window.contentViewController = NSHostingController(rootView: view)
        window.isReleasedWhenClosed = false

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if AppSettings.shared.isTestModeActive {
            AppSettings.shared.isTestModeActive = false
            AppSettings.shared.testTurnValue = 0
            OverlayWindowController.shared.stopOverlay()
        }
    }

    @objc private func recaptureScreen() {
        OverlayWindowController.shared.captureScreenAsync()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
