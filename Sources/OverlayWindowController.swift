import Foundation
import AppKit

public final class OverlayWindowController: NSObject {
    public static let shared = OverlayWindowController()
    
    private var window: NSWindow?
    private var metalView: MetalFoldView?
    private enum OverlayPhase {
        case hidden
        case capturing(UUID)
        case armed
        case visible
    }

    private var phase: OverlayPhase = .hidden
    private var requestedTurn: Double = 0
    private var wasActive = false
    
    public override init() {
        super.init()
        setupWindow()
        setupSleepObservers()
        
        // Connect intelligent hardware pre-arming
        LidSensor.shared.onPreArmCapture = { [weak self] in
            self?.captureScreenAsync()
        }
    }
    
    private func setupSleepObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.prepareFreshFrame()
        }
    }
    
    private func handleSleep() {
        metalView?.isPaused = true
        window?.alphaValue = 0.0
        AppSettings.shared.isScreenCaptureDormant = true
        phase = .hidden
    }
    
    private func setupWindow() {
        guard let screen = ScreenCapture.builtInScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.ignoresMouseEvents = true
        win.alphaValue = 0.0
        
        let mtkView = MetalFoldView(frame: win.contentView?.bounds ?? screen.frame)
        mtkView.autoresizingMask = [.width, .height]
        mtkView.isPaused = true
        win.contentView = mtkView
        
        self.window = win
        self.metalView = mtkView
        
        // One-time initial image load in background during app launch
        Task {
            if let img = await ScreenCapture.shared.fetchImage(for: screen) {
                await MainActor.run {
                    self.metalView?.updateImage(img)
                    AppSettings.shared.lastCaptureDate = Date()
                    AppSettings.shared.isScreenCaptureDormant = true
                }
            }
        }
    }
    
    public func update(turn: Double, angle: Double) {
        guard let win = self.window, let mv = self.metalView else { return }
        
        mv.currentTurn = Float(turn)
        
        requestedTurn = turn
        if turn > 0.0001 {
            wasActive = true
            switch phase {
            case .armed, .visible:
                phase = .visible
                mv.isPaused = false
                win.alphaValue = 1.0
                win.orderFrontRegardless()
            case .hidden:
                captureScreenAsync()
            case .capturing:
                break
            }
        } else {
            win.alphaValue = 0.0
            mv.isPaused = true
            if wasActive {
                wasActive = false
                phase = .hidden
            }
        }
    }
    
    public func stopOverlay() {
        wasActive = false
        requestedTurn = 0
        phase = .hidden
        window?.alphaValue = 0.0
        metalView?.isPaused = true
        metalView?.currentTurn = 0.0
    }
    
    public func captureScreenAsync() {
        if case .capturing = phase { return }
        let generation = UUID()
        phase = .capturing(generation)
        window?.alphaValue = 0.0
        metalView?.isPaused = true
        AppSettings.shared.isScreenCaptureDormant = false
        let screen = ScreenCapture.builtInScreen ?? NSScreen.main ?? NSScreen.screens.first
        
        Task {
            let image = await ScreenCapture.shared.fetchImage(for: screen)
            await MainActor.run {
                guard case .capturing(let currentGeneration) = self.phase,
                      currentGeneration == generation else { return }
                if let image {
                    self.metalView?.updateImage(image)
                    self.phase = .armed
                    AppSettings.shared.lastCaptureDate = Date()
                    if self.requestedTurn > 0.0001 {
                        self.phase = .visible
                        self.metalView?.isPaused = false
                        self.window?.alphaValue = 1.0
                        self.window?.orderFrontRegardless()
                    }
                } else {
                    self.phase = .hidden
                }
                AppSettings.shared.isScreenCaptureDormant = true
            }
        }
    }

    private func prepareFreshFrame() {
        phase = .hidden
        captureScreenAsync()
    }
}
