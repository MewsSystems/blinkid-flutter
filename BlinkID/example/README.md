# BlinkID Flutter Example App

Demonstrates the two scanning approaches exposed by the BlinkID Flutter plugin.

## What's in the example

### 1. Standard scanning (`performScan`)
Launches the built-in BlinkID UX — full-screen native camera scanning with automatic multi-language guidance, help screens, and onboarding dialog. Configurable via the settings screen:
- Scanning modules (Document Capture, MRZ, Barcode, VIZ)
- Session and step timeouts
- UX options (help button, onboarding, haptic feedback, preferred camera)
- Class filter (restrict accepted document types)
- Redaction (anonymize sensitive fields)

### 2. DirectAPI scanning
Extracts document data from static images selected from the device gallery:
- **MultiSide** — front + back image pair
- **SingleSide** — single image

### 3. Custom scanner UI (`BlinkIdScannerView`)
A fully custom Flutter scanning screen built on `BlinkIdScannerView`:
- Source: [`lib/custom_scanner_screen.dart`](lib/custom_scanner_screen.dart)
- Custom guidance text overlay with debounced animations
- Flip animation when the front side is complete
- Scan timeout with retry dialog
- Close button
- Success overlay

This is the reference implementation for `BlinkIdScannerView` + `BlinkIdScannerController`.

## Running the example

1. Set your license keys in `.env` (copy from `.env.example`):
   ```
   BLINKID_LICENSE_KEY_ANDROID=your-android-key
   BLINKID_LICENSE_KEY_IOS=your-ios-key
   ```
   Free trial keys available at [developer.microblink.com](https://developer.microblink.com/).

2. Run:
   ```bash
   flutter run
   ```

### iOS additional setup

If you see `Module 'blinkid-flutter' not found`, enable Swift Package Manager support:
```bash
flutter config --enable-swift-package-manager
flutter run
```

If the build fails with a deployment target error:
```bash
flutter build ios --config-only
flutter run
```

## Project structure

```
lib/
  main.dart                  — app entry point, settings screen
  custom_scanner_screen.dart — custom scanner UI reference implementation
```
