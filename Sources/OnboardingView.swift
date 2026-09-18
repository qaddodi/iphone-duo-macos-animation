import SwiftUI
import AppKit

public struct OnboardingView: View {
    @ObservedObject private var settings = AppSettings.shared
    public var onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                appIcon
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.20), radius: 14, y: 7)

                Text("Welcome to Tiltglass")
                    .font(.system(size: 27, weight: .bold, design: .rounded))

                Text("A local, hardware-synchronized optical layer for the physical motion of your MacBook display.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 430)
            }
            .padding(.top, 34)

            VStack(spacing: 16) {
                feature(
                    icon: "eye",
                    title: "Calibrated to how you sit",
                    detail: "Eye height and viewing distance shape perspective and refraction. Calibration stays separate from visual presets."
                )

                feature(
                    icon: "circle.hexagongrid.fill",
                    title: "Eight optical characters",
                    detail: "Natural, Duo, Frosted, Prism, Deep Glass, Crystal, Soft Focus, and Void can all be tuned live."
                )

                feature(
                    icon: "hand.raised.fill",
                    title: "Privacy by design",
                    detail: "Screen capture is processed locally for the fold effect. Tiltglass has no account system and does not upload your screen."
                )

                feature(
                    icon: "battery.100percent",
                    title: "Dormant until you move the lid",
                    detail: "The capture and Metal paths remain idle during normal use and pre-arm only as the lid enters the closing zone."
                )
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)

            VStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: settings.hasScreenRecordingPermission ? "checkmark.circle.fill" : "record.circle")
                        .foregroundStyle(settings.hasScreenRecordingPermission ? Color.green : Color.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.hasScreenRecordingPermission ? "Screen Recording is ready" : "Screen Recording permission")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(settings.hasScreenRecordingPermission ? "Tiltglass can capture the active display when the lid moves." : "Required only so the current display can become the local fold texture.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !settings.hasScreenRecordingPermission {
                        Button("Grant Access") {
                            if !ScreenCapture.shared.requestPermission() {
                                ScreenCapture.shared.openSettings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            )
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()

            HStack {
                Button("Privacy Settings") {
                    ScreenCapture.shared.openSettings()
                }

                Spacer()

                Button("Continue") {
                    settings.hasCompletedOnboarding = true
                    onDismiss?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
        }
        .frame(width: 560, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            settings.refreshPermissions()
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.55), .blue.opacity(0.55), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func feature(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.11))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
