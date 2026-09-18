import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1.0)
        : NSColor(red: 0.955, green: 0.965, blue: 0.978, alpha: 1.0)
}))

private let borderColor = Color.primary.opacity(0.10)

public struct LiquidGlassControlPanel: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var section: PanelSection = .setup
    @State private var newPresetName = ""
    @State private var showingPresetSave = false
    @State private var copiedResetCommand = false

    private let resetCommand = "tccutil reset ScreenCapture com.qaddodi.mactilt"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)

            HStack(spacing: 0) {
                sidebar

                Divider().opacity(0.45)

                ScrollView {
                    VStack(spacing: 16) {
                        presetBar

                        switch section {
                        case .setup:
                            setupView
                        case .looks:
                            looksView
                        case .behavior:
                            behaviorView
                        case .advanced:
                            advancedView
                        }
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 690)
        .background(panelBackground)
        .onAppear {
            settings.refreshPermissions()
            settings.refreshLaunchAtLogin()
        }
        .onDisappear {
            settings.isTestModeActive = false
            settings.testTurnValue = 0
            OverlayWindowController.shared.stopOverlay()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            appIcon
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Tiltglass")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Physical screen optics for your MacBook lid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill(
                title: settings.isSensorConnected ? "\(Int(settings.currentLidAngle))°" : "Sensor",
                subtitle: settings.isSensorConnected ? (settings.isClosing ? "Closing" : "Ready") : "Unavailable",
                active: settings.isSensorConnected
            )

            statusPill(
                title: settings.hasScreenRecordingPermission ? "Capture" : "Permission",
                subtitle: settings.hasScreenRecordingPermission ? "Ready" : "Required",
                active: settings.hasScreenRecordingPermission
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.65), .black.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(PanelSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.icon)
                            .frame(width: 18)
                        Text(item.title)
                            .fontWeight(section == item ? .semibold : .regular)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        section == item
                            ? Color.accentColor.opacity(0.13)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("Renderer")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(settings.performanceMode.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .padding(12)
        .frame(width: 142)
    }

    private var presetBar: some View {
        GlassCard {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRESET")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Section("Built-in") {
                            ForEach(AppSettings.builtInPresets) { preset in
                                Button {
                                    settings.applyPreset(id: preset.id)
                                } label: {
                                    if settings.activePresetID == preset.id {
                                        Label(preset.name, systemImage: "checkmark")
                                    } else {
                                        Text(preset.name)
                                    }
                                }
                            }
                        }

                        if !settings.userPresets.isEmpty {
                            Divider()
                            Section("My Presets") {
                                ForEach(settings.userPresets) { preset in
                                    Button {
                                        settings.applyPreset(id: preset.id)
                                    } label: {
                                        if settings.activePresetID == preset.id {
                                            Label(preset.name, systemImage: "checkmark")
                                        } else {
                                            Text(preset.name)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(settings.activePresetName)
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer()

                Button("Save Current") {
                    newPresetName = settings.activePresetIsUserPreset ? settings.activePresetName : ""
                    showingPresetSave = true
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingPresetSave, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Save Preset")
                            .font(.headline)
                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                showingPresetSave = false
                            }
                            Button("Save") {
                                settings.saveCurrentPreset(named: newPresetName)
                                newPresetName = ""
                                showingPresetSave = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(14)
                }

                if settings.activePresetIsUserPreset {
                    Button {
                        settings.deleteActiveUserPreset()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete this user preset")
                }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 16) {
            GlassCard(title: "VIEWING GEOMETRY", icon: "eye") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tiltglass uses your approximate eye position to tune perspective and refraction. The diagram is scaled consistently, so changing either value shows the geometric relationship in real time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LaptopGeometryView(
                        eyeHeightCM: settings.eyeHeightCM,
                        eyeDistanceCM: settings.eyeDistanceCM
                    )
                    .frame(height: 235)

                    valueSlider(
                        "Eye height",
                        value: customBinding(\.eyeHeightCM),
                        range: 20...90,
                        step: 1,
                        suffix: " cm"
                    )

                    valueSlider(
                        "Eye distance",
                        value: customBinding(\.eyeDistanceCM),
                        range: 30...120,
                        step: 1,
                        suffix: " cm"
                    )
                }
            }

            GlassCard(title: "QUICK START", icon: "wand.and.stars") {
                HStack(spacing: 14) {
                    quickStartItem(
                        icon: "1.circle.fill",
                        title: "Set eye position",
                        detail: "Match how you normally sit at the Mac."
                    )
                    quickStartItem(
                        icon: "2.circle.fill",
                        title: "Pick a preset",
                        detail: "Natural is the neutral starting point."
                    )
                    quickStartItem(
                        icon: "3.circle.fill",
                        title: "Close the lid",
                        detail: "The renderer follows the physical hinge."
                    )
                }
            }
        }
    }

    private var looksView: some View {
        VStack(spacing: 16) {
            GlassCard(title: "OPTICAL CHARACTER", icon: "circle.hexagongrid.fill") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    ForEach(OpticalEffectMode.allCases) { effect in
                        Button {
                            settings.effectMode = effect
                            settings.markCustom()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(effect.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    if settings.effectMode == effect {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text(effect.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                            .padding(10)
                            .background(
                                settings.effectMode == effect
                                    ? Color.accentColor.opacity(0.11)
                                    : Color.primary.opacity(0.025),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(
                                        settings.effectMode == effect
                                            ? Color.accentColor.opacity(0.38)
                                            : borderColor,
                                        lineWidth: 0.7
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            GlassCard(title: "GLASS TUNING", icon: "slider.horizontal.3") {
                VStack(spacing: 12) {
                    valueSlider("Blur", value: customBinding(\.blurStrength), range: 0...1.8, step: 0.01, digits: 2)
                    valueSlider("Refraction", value: customBinding(\.refractionStrength), range: 0...1.5, step: 0.01, digits: 2)
                    valueSlider("Chromatic split", value: customBinding(\.chromaticStrength), range: 0...1.5, step: 0.01, digits: 2)
                    valueSlider("Edge glow", value: customBinding(\.edgeGlow), range: 0...1.5, step: 0.01, digits: 2)
                    valueSlider("Reflection", value: customBinding(\.reflectionIntensity), range: 0...1.5, step: 0.01, digits: 2)
                    valueSlider("Saturation", value: customBinding(\.saturation), range: 0.55...1.35, step: 0.01, digits: 2)
                    valueSlider("Contrast", value: customBinding(\.contrast), range: 0.70...1.35, step: 0.01, digits: 2)
                    valueSlider("Darkness", value: customBinding(\.darknessStrength), range: 0.35...1.9, step: 0.01, digits: 2)
                }
            }
        }
    }

    private var behaviorView: some View {
        VStack(spacing: 16) {
            GlassCard(title: "MOTION RESPONSE", icon: "waveform.path.ecg") {
                VStack(spacing: 14) {
                    valueSlider(
                        "Closing response",
                        value: customBinding(\.closingFollowSpeed),
                        range: 4...36,
                        step: 1,
                        suffix: "×",
                        digits: 0
                    )
                    valueSlider(
                        "Opening response",
                        value: customBinding(\.openingFollowSpeed),
                        range: 4...40,
                        step: 1,
                        suffix: "×",
                        digits: 0
                    )

                    Divider().opacity(0.5)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Performance mode")
                                .font(.subheadline)
                            Text(settings.performanceMode.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: customEnumBinding(\.performanceMode)) {
                            ForEach(PerformanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .frame(width: 180)
                    }
                }
            }

            GlassCard(title: "APP BEHAVIOR", icon: "gearshape.2") {
                VStack(spacing: 12) {
                    Toggle(
                        "Launch Tiltglass at login",
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        )
                    )

                    Toggle("Show lid angle in the menu bar", isOn: $settings.showAngleInMenuBar)
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var advancedView: some View {
        VStack(spacing: 16) {
            GlassCard(title: "LID CALIBRATION", icon: "angle") {
                VStack(spacing: 12) {
                    valueSlider(
                        "Fold begins below",
                        value: $settings.startTiltAngle,
                        range: 75...135,
                        step: 1,
                        suffix: "°",
                        digits: 0
                    )

                    valueSlider(
                        "Fully closed by",
                        value: $settings.endTiltAngle,
                        range: 0...25,
                        step: 1,
                        suffix: "°",
                        digits: 0
                    )

                    valueSlider("Blur curve", value: customBinding(\.blurCurve), range: 0.5...2.3, step: 0.05, digits: 2)
                    valueSlider("Perspective strength", value: customBinding(\.perspectiveStrength), range: 0.45...1.65, step: 0.01, digits: 2)
                }
            }

            GlassCard(title: "CAPTURE SOURCE", icon: "rectangle.on.rectangle") {
                HStack {
                    Text("Image source")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $settings.imageSourceMode) {
                        ForEach(ImageSourceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .frame(width: 190)
                }

                if settings.imageSourceMode == .customImage {
                    HStack {
                        Text(settings.customImagePath.isEmpty ? "No image selected" : URL(fileURLWithPath: settings.customImagePath).lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Choose Image...") {
                            selectCustomImage()
                        }
                    }
                    .padding(.top, 8)
                }
            }

            GlassCard(title: "VALIDATION", icon: "stethoscope") {
                VStack(spacing: 12) {
                    diagnosticRow(
                        title: "Lid sensor",
                        detail: settings.sensorStatusMessage,
                        good: settings.isSensorConnected
                    )

                    diagnosticRow(
                        title: "Screen Recording",
                        detail: settings.hasScreenRecordingPermission ? "Permission active" : "Permission required",
                        good: settings.hasScreenRecordingPermission
                    )

                    HStack {
                        Button("Re-check Permission") {
                            settings.refreshPermissions()
                        }

                        if !settings.hasScreenRecordingPermission {
                            Button("Open Privacy Settings") {
                                if !ScreenCapture.shared.requestPermission() {
                                    ScreenCapture.shared.openSettings()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button(copiedResetCommand ? "Copied" : "Copy TCC Reset") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(resetCommand, forType: .string)
                                copiedResetCommand = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copiedResetCommand = false
                                }
                            }
                        }

                        Spacer()

                        Button("Refresh Snapshot") {
                            OverlayWindowController.shared.captureScreenAsync()
                        }
                    }
                    .controlSize(.small)

                    Divider().opacity(0.5)

                    Toggle("Enable diagnostic fold control", isOn: $settings.isTestModeActive)
                        .toggleStyle(.switch)

                    if settings.isTestModeActive {
                        HStack {
                            Text("Test fold")
                                .font(.caption)
                            Slider(value: $settings.testTurnValue, in: 0...1)
                            Text("\(Int(settings.testTurnValue * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func statusPill(title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: 0.5))
    }

    private func quickStartItem(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func diagnosticRow(title: String, detail: String, good: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(good ? Color.green : Color.orange)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String = "",
        digits: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.*f", digits, value.wrappedValue) + suffix)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func customBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: {
                settings[keyPath: keyPath] = $0
                settings.markCustom()
            }
        )
    }

    private func customEnumBinding<T>(_ keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: {
                settings[keyPath: keyPath] = $0
                settings.markCustom()
            }
        )
    }

    private func selectCustomImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.customImagePath = url.path
        }
    }
}

private enum PanelSection: String, CaseIterable, Identifiable {
    case setup
    case looks
    case behavior
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setup: return "Setup"
        case .looks: return "Looks"
        case .behavior: return "Behavior"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .setup: return "eye"
        case .looks: return "circle.hexagongrid"
        case .behavior: return "waveform.path"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

private struct GlassCard<Content: View>: View {
    private let title: String?
    private let icon: String?
    private let content: Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(borderColor, lineWidth: 0.6)
        )
    }
}

private struct LaptopGeometryView: View {
    let eyeHeightCM: Double
    let eyeDistanceCM: Double

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let scale = min((w - 85) / 125.0, (h - 40) / 95.0)
            let hingeX = 54.0
            let baseY = h - 28.0
            let deckLength = 23.8 * scale
            let displayHeight = 21.0 * scale
            let eyeX = min(w - 28, hingeX + eyeDistanceCM * scale)
            let eyeY = max(22, baseY - eyeHeightCM * scale)

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: hingeX, y: baseY))
                    path.addLine(to: CGPoint(x: hingeX + deckLength, y: baseY))

                    path.move(to: CGPoint(x: hingeX, y: baseY))
                    path.addLine(to: CGPoint(x: hingeX + displayHeight * 0.20, y: baseY - displayHeight))

                    path.move(to: CGPoint(x: hingeX, y: baseY))
                    path.addLine(to: CGPoint(x: eyeX, y: baseY))

                    path.move(to: CGPoint(x: eyeX, y: baseY))
                    path.addLine(to: CGPoint(x: eyeX, y: eyeY))
                }
                .stroke(Color.secondary.opacity(0.60), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [5, 5]))

                Path { path in
                    path.move(to: CGPoint(x: hingeX, y: baseY))
                    path.addLine(to: CGPoint(x: hingeX + deckLength, y: baseY))
                    path.move(to: CGPoint(x: hingeX, y: baseY))
                    path.addLine(to: CGPoint(x: hingeX + displayHeight * 0.20, y: baseY - displayHeight))
                }
                .stroke(Color.primary.opacity(0.82), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 13, height: 13)
                    .position(x: eyeX, y: eyeY)

                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .position(x: eyeX, y: eyeY)

                Text("\(Int(eyeHeightCM)) cm")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .position(x: min(w - 35, eyeX + 30), y: (eyeY + baseY) / 2)

                Text("\(Int(eyeDistanceCM)) cm")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .position(x: (hingeX + eyeX) / 2, y: baseY + 13)

                Text("hinge")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .position(x: hingeX, y: baseY + 13)
            }
        }
        .padding(.horizontal, 4)
        .background(
            Color.primary.opacity(0.022),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
}
