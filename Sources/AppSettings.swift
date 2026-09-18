import Foundation
import Combine
import SwiftUI
import ServiceManagement

public enum ImageSourceMode: Int, CaseIterable, Identifiable, Codable {
    case liveCapture = 0
    case desktopWallpaper = 1
    case bundledArtwork = 2
    case customImage = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .liveCapture: return "Live Screen"
        case .desktopWallpaper: return "Wallpaper"
        case .bundledArtwork: return "Bundled Artwork"
        case .customImage: return "Custom Image"
        }
    }
}

public enum OpticalEffectMode: Int, CaseIterable, Identifiable, Codable {
    case natural = 0
    case duo = 1
    case frosted = 2
    case prism = 3
    case deepGlass = 4
    case crystal = 5
    case softFocus = 6
    case void = 7

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .natural: return "Natural Glass"
        case .duo: return "Duo"
        case .frosted: return "Frosted"
        case .prism: return "Prism"
        case .deepGlass: return "Deep Glass"
        case .crystal: return "Crystal"
        case .softFocus: return "Soft Focus"
        case .void: return "Void"
        }
    }

    public var subtitle: String {
        switch self {
        case .natural: return "Balanced refraction and matte blur"
        case .duo: return "Layered bend with bright glass edges"
        case .frosted: return "Dense diffusion with soft texture"
        case .prism: return "Chromatic separation and caustic edges"
        case .deepGlass: return "Dark, dimensional optical depth"
        case .crystal: return "Sharper glass with crisp highlights"
        case .softFocus: return "Bloomed diffusion with gentle contrast"
        case .void: return "Aggressive falloff into near-black"
        }
    }
}

public enum PerformanceMode: Int, CaseIterable, Identifiable, Codable {
    case efficiency = 0
    case balanced = 1
    case quality = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .efficiency: return "Efficiency"
        case .balanced: return "Balanced"
        case .quality: return "Max Quality"
        }
    }

    public var subtitle: String {
        switch self {
        case .efficiency: return "Lower sample count and frame rate"
        case .balanced: return "Default for most Macs"
        case .quality: return "Highest optical sample count"
        }
    }
}

public struct TiltPreset: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool
    public var effectMode: OpticalEffectMode
    public var performanceMode: PerformanceMode
    public var blurStrength: Double
    public var refractionStrength: Double
    public var chromaticStrength: Double
    public var edgeGlow: Double
    public var reflectionIntensity: Double
    public var saturation: Double
    public var contrast: Double
    public var darknessStrength: Double
    public var blurCurve: Double
    public var perspectiveStrength: Double
    public var closingFollowSpeed: Double
    public var openingFollowSpeed: Double
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private let kHasCompletedOnboarding = "mactilt_hasCompletedOnboarding"
    private let kStartTiltAngle = "mactilt_startTiltAngle"
    private let kEndTiltAngle = "mactilt_endTiltAngle"
    private let kClosingFollowSpeed = "mactilt_closingFollowSpeed"
    private let kOpeningFollowSpeed = "mactilt_openingFollowSpeed"
    private let kImageSourceMode = "mactilt_imageSourceMode"
    private let kCustomImagePath = "mactilt_customImagePath"
    private let kShowAngleInMenuBar = "mactilt_showAngleInMenuBar"

    private let kEffectMode = "tiltglass_effectMode"
    private let kPerformanceMode = "tiltglass_performanceMode"
    private let kBlurStrength = "tiltglass_blurStrength"
    private let kRefractionStrength = "tiltglass_refractionStrength"
    private let kChromaticStrength = "tiltglass_chromaticStrength"
    private let kEdgeGlow = "tiltglass_edgeGlow"
    private let kReflectionIntensity = "tiltglass_reflectionIntensity"
    private let kSaturation = "tiltglass_saturation"
    private let kContrast = "tiltglass_contrast"
    private let kDarknessStrength = "tiltglass_darknessStrength"
    private let kBlurCurve = "tiltglass_blurCurve"
    private let kPerspectiveStrength = "tiltglass_perspectiveStrength"
    private let kEyeHeight = "tiltglass_eyeHeightCM"
    private let kEyeDistance = "tiltglass_eyeDistanceCM"
    private let kActivePresetID = "tiltglass_activePresetID"
    private let kUserPresets = "tiltglass_userPresets"
    private let kMigrationVersion = "tiltglass_migrationVersion"

    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: kHasCompletedOnboarding) }
    }

    @Published public var startTiltAngle: Double {
        didSet { defaults.set(startTiltAngle, forKey: kStartTiltAngle) }
    }

    @Published public var endTiltAngle: Double {
        didSet { defaults.set(endTiltAngle, forKey: kEndTiltAngle) }
    }

    @Published public var closingFollowSpeed: Double {
        didSet { defaults.set(closingFollowSpeed, forKey: kClosingFollowSpeed) }
    }

    @Published public var openingFollowSpeed: Double {
        didSet { defaults.set(openingFollowSpeed, forKey: kOpeningFollowSpeed) }
    }

    @Published public var imageSourceMode: ImageSourceMode {
        didSet { defaults.set(imageSourceMode.rawValue, forKey: kImageSourceMode) }
    }

    @Published public var customImagePath: String {
        didSet { defaults.set(customImagePath, forKey: kCustomImagePath) }
    }

    @Published public var showAngleInMenuBar: Bool {
        didSet {
            defaults.set(showAngleInMenuBar, forKey: kShowAngleInMenuBar)
            MenuBarController.shared.refreshMenuBarTitle()
        }
    }

    @Published public var effectMode: OpticalEffectMode {
        didSet { defaults.set(effectMode.rawValue, forKey: kEffectMode) }
    }

    @Published public var performanceMode: PerformanceMode {
        didSet { defaults.set(performanceMode.rawValue, forKey: kPerformanceMode) }
    }

    @Published public var blurStrength: Double {
        didSet { defaults.set(blurStrength, forKey: kBlurStrength) }
    }

    @Published public var refractionStrength: Double {
        didSet { defaults.set(refractionStrength, forKey: kRefractionStrength) }
    }

    @Published public var chromaticStrength: Double {
        didSet { defaults.set(chromaticStrength, forKey: kChromaticStrength) }
    }

    @Published public var edgeGlow: Double {
        didSet { defaults.set(edgeGlow, forKey: kEdgeGlow) }
    }

    @Published public var reflectionIntensity: Double {
        didSet { defaults.set(reflectionIntensity, forKey: kReflectionIntensity) }
    }

    @Published public var saturation: Double {
        didSet { defaults.set(saturation, forKey: kSaturation) }
    }

    @Published public var contrast: Double {
        didSet { defaults.set(contrast, forKey: kContrast) }
    }

    @Published public var darknessStrength: Double {
        didSet { defaults.set(darknessStrength, forKey: kDarknessStrength) }
    }

    @Published public var blurCurve: Double {
        didSet { defaults.set(blurCurve, forKey: kBlurCurve) }
    }

    @Published public var perspectiveStrength: Double {
        didSet { defaults.set(perspectiveStrength, forKey: kPerspectiveStrength) }
    }

    @Published public var eyeHeightCM: Double {
        didSet { defaults.set(eyeHeightCM, forKey: kEyeHeight) }
    }

    @Published public var eyeDistanceCM: Double {
        didSet { defaults.set(eyeDistanceCM, forKey: kEyeDistance) }
    }

    @Published public var activePresetID: String {
        didSet { defaults.set(activePresetID, forKey: kActivePresetID) }
    }

    @Published public private(set) var userPresets: [TiltPreset] = []
    @Published public private(set) var launchAtLogin: Bool = false

    @Published public var isTestModeActive: Bool = false {
        didSet {
            if !isTestModeActive {
                testTurnValue = 0.0
            }
        }
    }

    @Published public var testTurnValue: Double = 0.0
    @Published public var currentLidAngle: Double = 120.0
    @Published public var isSensorConnected: Bool = false
    @Published public var isClosing: Bool = false
    @Published public var sensorStatusMessage: String = "Initializing sensor..."
    @Published public var hasScreenRecordingPermission: Bool = false
    @Published public var lastCaptureDate: Date? = nil
    @Published public var isScreenCaptureDormant: Bool = true

    public static let builtInPresets: [TiltPreset] = [
        TiltPreset(
            id: "builtin.natural", name: "Natural", isBuiltIn: true,
            effectMode: .natural, performanceMode: .balanced,
            blurStrength: 0.55, refractionStrength: 0.35, chromaticStrength: 0.05,
            edgeGlow: 0.16, reflectionIntensity: 0.18, saturation: 1.0,
            contrast: 1.0, darknessStrength: 1.0, blurCurve: 1.25,
            perspectiveStrength: 1.0, closingFollowSpeed: 16.0, openingFollowSpeed: 20.0
        ),
        TiltPreset(
            id: "builtin.duo", name: "Duo", isBuiltIn: true,
            effectMode: .duo, performanceMode: .balanced,
            blurStrength: 0.82, refractionStrength: 0.78, chromaticStrength: 0.16,
            edgeGlow: 0.52, reflectionIntensity: 0.62, saturation: 1.05,
            contrast: 1.02, darknessStrength: 0.95, blurCurve: 1.30,
            perspectiveStrength: 1.08, closingFollowSpeed: 18.0, openingFollowSpeed: 22.0
        ),
        TiltPreset(
            id: "builtin.deep", name: "Deep Glass", isBuiltIn: true,
            effectMode: .deepGlass, performanceMode: .quality,
            blurStrength: 0.95, refractionStrength: 0.58, chromaticStrength: 0.05,
            edgeGlow: 0.32, reflectionIntensity: 0.82, saturation: 0.90,
            contrast: 1.08, darknessStrength: 1.28, blurCurve: 1.45,
            perspectiveStrength: 1.16, closingFollowSpeed: 13.0, openingFollowSpeed: 17.0
        ),
        TiltPreset(
            id: "builtin.frosted", name: "Frosted", isBuiltIn: true,
            effectMode: .frosted, performanceMode: .quality,
            blurStrength: 1.35, refractionStrength: 0.24, chromaticStrength: 0.02,
            edgeGlow: 0.18, reflectionIntensity: 0.28, saturation: 0.88,
            contrast: 0.96, darknessStrength: 1.0, blurCurve: 1.50,
            perspectiveStrength: 1.0, closingFollowSpeed: 14.0, openingFollowSpeed: 18.0
        ),
        TiltPreset(
            id: "builtin.prism", name: "Prism", isBuiltIn: true,
            effectMode: .prism, performanceMode: .quality,
            blurStrength: 0.52, refractionStrength: 0.92, chromaticStrength: 1.0,
            edgeGlow: 0.64, reflectionIntensity: 0.66, saturation: 1.12,
            contrast: 1.03, darknessStrength: 0.92, blurCurve: 1.15,
            perspectiveStrength: 1.08, closingFollowSpeed: 16.0, openingFollowSpeed: 20.0
        ),
        TiltPreset(
            id: "builtin.void", name: "Void", isBuiltIn: true,
            effectMode: .void, performanceMode: .balanced,
            blurStrength: 0.72, refractionStrength: 0.20, chromaticStrength: 0.0,
            edgeGlow: 0.06, reflectionIntensity: 0.10, saturation: 0.76,
            contrast: 1.16, darknessStrength: 1.68, blurCurve: 1.35,
            perspectiveStrength: 1.15, closingFollowSpeed: 11.0, openingFollowSpeed: 15.0
        )
    ]

    private init() {
        hasCompletedOnboarding = defaults.bool(forKey: kHasCompletedOnboarding)
        startTiltAngle = Self.value(defaults, key: kStartTiltAngle, fallback: 115.0)
        endTiltAngle = Self.value(defaults, key: kEndTiltAngle, fallback: 3.0)

        let legacyFollow = Self.value(defaults, key: "mactilt_followSpeed", fallback: 16.0)
        closingFollowSpeed = Self.value(defaults, key: kClosingFollowSpeed, fallback: legacyFollow)
        openingFollowSpeed = Self.value(defaults, key: kOpeningFollowSpeed, fallback: 20.0)

        let savedSource = defaults.object(forKey: kImageSourceMode) != nil ? defaults.integer(forKey: kImageSourceMode) : ImageSourceMode.liveCapture.rawValue
        imageSourceMode = ImageSourceMode(rawValue: savedSource) ?? .liveCapture
        customImagePath = defaults.string(forKey: kCustomImagePath) ?? ""
        showAngleInMenuBar = defaults.object(forKey: kShowAngleInMenuBar) != nil ? defaults.bool(forKey: kShowAngleInMenuBar) : true

        effectMode = OpticalEffectMode(rawValue: defaults.integer(forKey: kEffectMode)) ?? .natural
        performanceMode = PerformanceMode(rawValue: defaults.integer(forKey: kPerformanceMode)) ?? .balanced

        blurStrength = Self.value(defaults, key: kBlurStrength, fallback: Self.value(defaults, key: "mactilt_blurStrength", fallback: 0.55))
        refractionStrength = Self.value(defaults, key: kRefractionStrength, fallback: 0.35)
        chromaticStrength = Self.value(defaults, key: kChromaticStrength, fallback: 0.05)
        edgeGlow = Self.value(defaults, key: kEdgeGlow, fallback: 0.16)
        reflectionIntensity = Self.value(defaults, key: kReflectionIntensity, fallback: Self.value(defaults, key: "mactilt_reflectionIntensity", fallback: 0.18))
        saturation = Self.value(defaults, key: kSaturation, fallback: 1.0)
        contrast = Self.value(defaults, key: kContrast, fallback: 1.0)
        darknessStrength = Self.value(defaults, key: kDarknessStrength, fallback: Self.value(defaults, key: "mactilt_darknessStrength", fallback: 1.0))
        blurCurve = Self.value(defaults, key: kBlurCurve, fallback: Self.value(defaults, key: "mactilt_blurCurve", fallback: 1.25))
        perspectiveStrength = Self.value(defaults, key: kPerspectiveStrength, fallback: Self.value(defaults, key: "mactilt_perspectiveStrength", fallback: 1.0))
        eyeHeightCM = Self.value(defaults, key: kEyeHeight, fallback: 45.0)
        eyeDistanceCM = Self.value(defaults, key: kEyeDistance, fallback: 60.0)
        activePresetID = defaults.string(forKey: kActivePresetID) ?? "builtin.natural"

        migrateLegacyPreferencesIfNeeded()
        loadUserPresets()
        refreshLaunchAtLogin()
        refreshPermissions()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
            self?.refreshLaunchAtLogin()
        }
    }

    private static func value(_ defaults: UserDefaults, key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) != nil ? defaults.double(forKey: key) : fallback
    }

    private func migrateLegacyPreferencesIfNeeded() {
        let version = defaults.integer(forKey: kMigrationVersion)
        guard version < 1 else { return }

        let legacyMap: [(String, String)] = [
            ("mactilt_blurStrength", kBlurStrength),
            ("mactilt_reflectionIntensity", kReflectionIntensity),
            ("mactilt_blurCurve", kBlurCurve),
            ("mactilt_perspectiveStrength", kPerspectiveStrength),
            ("mactilt_darknessStrength", kDarknessStrength)
        ]

        for (oldKey, newKey) in legacyMap {
            if defaults.object(forKey: newKey) == nil, let value = defaults.object(forKey: oldKey) {
                defaults.set(value, forKey: newKey)
            }
        }

        defaults.set(1, forKey: kMigrationVersion)
    }

    public var allPresets: [TiltPreset] {
        Self.builtInPresets + userPresets
    }

    public var activePresetName: String {
        allPresets.first(where: { $0.id == activePresetID })?.name ?? "Custom"
    }

    public var activePresetIsUserPreset: Bool {
        userPresets.contains(where: { $0.id == activePresetID })
    }

    public func applyPreset(id: String) {
        guard let preset = allPresets.first(where: { $0.id == id }) else { return }
        effectMode = preset.effectMode
        performanceMode = preset.performanceMode
        blurStrength = preset.blurStrength
        refractionStrength = preset.refractionStrength
        chromaticStrength = preset.chromaticStrength
        edgeGlow = preset.edgeGlow
        reflectionIntensity = preset.reflectionIntensity
        saturation = preset.saturation
        contrast = preset.contrast
        darknessStrength = preset.darknessStrength
        blurCurve = preset.blurCurve
        perspectiveStrength = preset.perspectiveStrength
        closingFollowSpeed = preset.closingFollowSpeed
        openingFollowSpeed = preset.openingFollowSpeed
        activePresetID = preset.id
    }

    public func markCustom() {
        if activePresetID != "custom" {
            activePresetID = "custom"
        }
    }

    public func saveCurrentPreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let existing = userPresets.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        let id = existing?.id ?? "user.\(UUID().uuidString)"
        let preset = currentSnapshot(id: id, name: name)

        if let index = userPresets.firstIndex(where: { $0.id == id }) {
            userPresets[index] = preset
        } else {
            userPresets.append(preset)
        }

        activePresetID = id
        persistUserPresets()
        MenuBarController.shared.rebuildPresetMenu()
    }

    public func deleteActiveUserPreset() {
        guard let index = userPresets.firstIndex(where: { $0.id == activePresetID }) else { return }
        userPresets.remove(at: index)
        persistUserPresets()
        applyPreset(id: "builtin.natural")
        MenuBarController.shared.rebuildPresetMenu()
    }

    private func currentSnapshot(id: String, name: String) -> TiltPreset {
        TiltPreset(
            id: id, name: name, isBuiltIn: false,
            effectMode: effectMode, performanceMode: performanceMode,
            blurStrength: blurStrength, refractionStrength: refractionStrength,
            chromaticStrength: chromaticStrength, edgeGlow: edgeGlow,
            reflectionIntensity: reflectionIntensity, saturation: saturation,
            contrast: contrast, darknessStrength: darknessStrength,
            blurCurve: blurCurve, perspectiveStrength: perspectiveStrength,
            closingFollowSpeed: closingFollowSpeed, openingFollowSpeed: openingFollowSpeed
        )
    }

    private func loadUserPresets() {
        guard let data = defaults.data(forKey: kUserPresets),
              let decoded = try? JSONDecoder().decode([TiltPreset].self, from: data) else {
            userPresets = []
            return
        }
        userPresets = decoded.filter { !$0.isBuiltIn }
    }

    private func persistUserPresets() {
        if let data = try? JSONEncoder().encode(userPresets) {
            defaults.set(data, forKey: kUserPresets)
        }
    }

    public func refreshPermissions() {
        hasScreenRecordingPermission = ScreenCapture.shared.hasPermission()
        Task {
            let verified = await ScreenCapture.shared.verifyPermissionAsync()
            await MainActor.run {
                self.hasScreenRecordingPermission = verified
            }
        }
    }

    public func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Tiltglass] Launch at login change failed: \(error)")
        }
        refreshLaunchAtLogin()
    }

    public func normalizedTurn(for angle: Double, isLidClosing: Bool) -> Double {
        if isTestModeActive {
            return min(1.0, max(0.0, testTurnValue))
        }

        if angle >= startTiltAngle {
            return 0.0
        }

        if angle <= endTiltAngle {
            return 1.0
        }

        let range = startTiltAngle - endTiltAngle
        guard range > 0.001 else { return 0.0 }

        let rawProgress = (startTiltAngle - angle) / range
        return min(1.0, max(0.0, rawProgress))
    }
}
