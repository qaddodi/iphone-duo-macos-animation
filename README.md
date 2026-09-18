# Tiltglass

Tiltglass is a native macOS menu-bar utility that turns physical MacBook lid motion into a real-time optical fold effect.

## Product structure

- **Setup**: calibrated eye height and viewing distance with a scaled side-profile diagram
- **Looks**: eight live optical modes and direct glass controls
- **Behavior**: independent opening and closing response, performance mode, login behavior
- **Advanced**: lid thresholds, source selection, permissions, capture refresh, diagnostics

## Presets

Built-in presets are protected and include Natural, Duo, Deep Glass, Frosted, Prism, and Void. Users can save and name their own presets and switch them from the menu bar.

Calibration is intentionally separate from visual presets.

## Privacy

The active display is captured only for the local fold texture. No screen image is uploaded by Tiltglass.

The bundle identifier remains com.qaddodi.mactilt so an existing Screen Recording permission can continue to apply across the product rename.

## Build

Run ./build.sh or use the GitHub Actions workflow. The workflow produces a zipped Tiltglass.app and a source archive.

## Release signing

scripts/package_release.sh uses ad-hoc signing by default. Set DEVELOPER_ID_APPLICATION to a Developer ID Application identity for distribution signing. Set NOTARY_PROFILE to a configured notarytool keychain profile to submit and staple automatically.
