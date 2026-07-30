# BlinkID v8 Custom UI — Implementation Plan

## Context

Kiosk migrated to BlinkID v8 (`blinkid_flutter: ^8000.0.0` from pub.dev) on branch `GX-blinkid-v8-stage1`. The v8 package only exposes `performScan()` — a full-screen native Activity/modal with no string, locale, colour, or UI customisation hooks. Mews has an existing fork (`github.com/MewsSystems/blinkid-flutter`) but it is v6-era and not wired into the pubspec.

Goal: expand the fork to v8, add a `BlinkIdScannerView` PlatformView widget that owns the camera layer and exposes detection guidance callbacks to Flutter, allowing Kiosk to render its own overlay with translated strings, Mews branding, and animations. Feature-flagged so the native `performScan()` path remains available as fallback.

---

## Key Facts Discovered

### v8 API surface (pub.dev package)
- `performScan()` — only public entry point; launches full-screen native UI
- `BlinkIdScanningUxSettings` — only 4 fields (`showHelpButton`, `showOnboardingDialog`, `allowHapticFeedback`, `preferredCamera`). No string/colour overrides.
- No PlatformView, no event channel, no frame callbacks.

### v8 native SDK — custom camera IS supported
- **Android**: separate `com.microblink:blinkid-core` artifact (no UI, no camera). Feed `CameraX ImageProxy` via `InputImage.createFromCameraXImageProxy(imageProxy, rotation)` → `session.process(inputImage)`.
- **iOS**: `BlinkID.xcframework` (core) separate from `BlinkIDUX`. Feed `CMSampleBuffer` from `AVCaptureVideoDataOutput` via `InputImage(cameraFrame: CameraFrame(buffer: sampleBuffer, orientation: .portrait))` → `session.process(inputImage:)`.
- Both platforms ship first-party `CustomUI` samples in their repos:
  - Android: `BlinkIDSample/direct-api-sample-app/`
  - iOS: `Samples/BundledResources/BlinkIDSample/CustomUI/`

### Existing Mews fork
- Location: `github.com/MewsSystems/blinkid-flutter`
- Status: v6-era, latest commit bumps to v6.10.0. Not referenced by kiosk pubspec.
- v6 had `MicroblinkScannerView : PlatformView` on both platforms using `RecognizerRunnerView` (Android) and `MBCustomOverlayViewController` (iOS) — **both APIs are removed in v8**.

---

## Architecture

```
blinkid_flutter fork (MewsSystems/blinkid-flutter, rebased to v8 upstream tag)
├── performScan()                  ← untouched — full BlinkID native UI
└── BlinkIdScannerView widget      ← NEW: PlatformView + event channel
    ├── Android: CameraX ImageAnalyzer → blinkid-core session.process()
    ├── iOS: AVFoundation AVCaptureVideoDataOutput → BlinkID.xcframework session.process()
    └── Dart: BlinkIdScannerController (ChangeNotifier) + guidanceStream

Kiosk (feature-flagged)
├── flag OFF → performScan() path (current behaviour)
└── flag ON  → BlinkIdScannerView + Kiosk Flutter overlay (translated strings, animations)
```

---

## Dart API Design

### Controller (owns lifecycle + state)

```dart
// lib/src/blinkid_scanner_controller.dart
class BlinkIdScannerController extends ChangeNotifier {
  BlinkIdScannerStatus get status => _status;          // for ListenableBuilder
  Stream<BlinkIdGuidance> get guidanceStream => ...;   // continuous detection hints

  Future<void> initialize(
    BlinkIdSdkSettings sdkSettings,
    BlinkIdSessionSettings sessionSettings,
  );

  /// Completes with result, throws on cancel/error.
  Future<BlinkIdScanningResult> scan();

  void cancel();

  @override
  void dispose();
}

enum BlinkIdScannerStatus { uninitialized, initializing, ready, scanning, done, error }
```

### Guidance states (sealed class, not enum — allows data per case later)

```dart
// lib/src/blinkid_guidance.dart
sealed class BlinkIdGuidance {
  const factory BlinkIdGuidance.searching()     = _Searching;
  const factory BlinkIdGuidance.tooFar()        = _TooFar;
  const factory BlinkIdGuidance.tooClose()      = _TooClose;
  const factory BlinkIdGuidance.tilted()        = _Tilted;
  const factory BlinkIdGuidance.holdStill()     = _HoldStill;
  const factory BlinkIdGuidance.flipDocument()  = _FlipDocument;
}
```

These map 1:1 to `DetectionStatus` / `FrameProcessResult` values returned by `session.process()` on both platforms.

### View (dumb — only renders camera surface)

```dart
// lib/src/blinkid_scanner_view.dart
class BlinkIdScannerView extends StatelessWidget {
  const BlinkIdScannerView({required this.controller, super.key});
  final BlinkIdScannerController controller;

  @override
  Widget build(BuildContext context) => switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidView(
        viewType: 'com.microblink.blinkid/scanner_view',
        creationParams: controller._creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: controller._onPlatformViewCreated,
      ),
    TargetPlatform.iOS => UiKitView(
        viewType: 'com.microblink.blinkid/scanner_view',
        creationParams: controller._creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: controller._onPlatformViewCreated,
      ),
    _ => throw UnsupportedError('BlinkIdScannerView unsupported on $defaultTargetPlatform'),
  };
}
```

### Kiosk usage pattern

```dart
class _DocumentScannerState extends State<DocumentScannerDialog> {
  late final _controller = BlinkIdScannerController();

  @override
  void initState() {
    super.initState();
    _controller
      .initialize(sdkSettings, sessionSettings)
      .then((_) => _controller.scan())
      .then(widget.onResult)
      .catchError(widget.onError);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    BlinkIdScannerView(controller: _controller),   // camera surface
    StreamBuilder<BlinkIdGuidance>(
      stream: _controller.guidanceStream,
      builder: (ctx, snap) => _GuidanceOverlay(snap.data),  // Kiosk Flutter UI
    ),
  ]);
}
```

---

## Native Implementation

### Android

**File:** `android/src/main/kotlin/com/microblink/blinkid/flutter/`

New files:
- `BlinkIdScannerViewFactory.kt` — `PlatformViewFactory`, registered as `"com.microblink.blinkid/scanner_view"` in `BlinkidFlutterPlugin.onAttachedToActivity`
- `BlinkIdScannerView.kt` — `PlatformView + LifecycleOwner`
  - Creates a `PreviewView` (CameraX) as the native view returned by `getView()`
  - Sets up `ImageAnalysis` use case; analyzer calls `session.process(InputImage.createFromCameraXImageProxy(imageProxy, rotation))`
  - Forwards `FrameProcessResult.detectionStatus` over per-view `EventChannel` at `com.microblink.blinkid.flutter/scanner/<id>/guidance`
  - Sends final result over `MethodChannel` at `com.microblink.blinkid.flutter/scanner/<id>`

**Gradle:** depend on `com.microblink:blinkid-core` only (drop `blinkid-ux` or keep it isolated to the `performScan` code path).

**HC++ (Texture Layer Hybrid Composition):** Flutter 3.x uses TLHC by default for `AndroidView` when the view uses `TextureView`. CameraX `PreviewView` defaults to `TextureView` — HC++ is automatic. No extra configuration needed.

### iOS

**File:** `ios/blinkid_flutter/Sources/blinkid_flutter/`

New files:
- `BlinkIdScannerViewFactory.swift` — `NSObject + FlutterPlatformViewFactory`, registered as `"com.microblink.blinkid/scanner_view"`
- `BlinkIdScannerView.swift` — `NSObject + FlutterPlatformView`
  - Owns `AVCaptureSession` with `AVCaptureVideoDataOutput`
  - `captureOutput(_:didOutput:from:)` delegate wraps `CMSampleBuffer` → `InputImage(cameraFrame: CameraFrame(buffer:orientation:))` → `session.process(inputImage:)`
  - Forwards `FrameProcessResult` guidance over `FlutterEventChannel` at `com.microblink.blinkid.flutter/scanner/<id>/guidance`
  - Sends final result over `FlutterMethodChannel` at `com.microblink.blinkid.flutter/scanner/<id>`

**Framework:** `import BlinkID` only (core). Do not import `BlinkIDUX`.

---

## Fork Setup Steps

1. In `github.com/MewsSystems/blinkid-flutter`: reset `master` to upstream v8 tag (`8000.0.0`) — do NOT merge v6 code, start clean.
2. Create branch `feature/custom-scanner-view`.
3. Add new files listed above; keep all existing `performScan` code untouched.
4. Publish as git dependency in kiosk `pubspec.yaml`:

```yaml
blinkid_flutter:
  git:
    url: https://github.com/MewsSystems/blinkid-flutter.git
    ref: feature/custom-scanner-view
```

---

## Kiosk Feature Flag

```dart
// lib/features/feature_flags/models/feature_flag.dart
// Add:
customDocumentScannerUI,
```

```dart
// lib/features/scanning/widgets/document_scanner_dialog.dart
// Wrap existing scanner widget:
if (sl<FeatureFlags>().isFeatureEnabled(FeatureFlag.customDocumentScannerUI))
  _CustomScannerOverlay(...)
else
  _NativeScannerDialog(...)  // existing performScan() path
```

---

## Reference Material

- Android native SDK docs + samples: https://github.com/microblink/blinkid-android — see `BlinkIDSample/direct-api-sample-app/`
- iOS native SDK docs + samples: https://github.com/microblink/blinkid-ios — see `Samples/BundledResources/BlinkIDSample/CustomUI/`
- Upstream Flutter plugin: https://github.com/BlinkID/blinkid-flutter (v8 tag `8000.0.0`)
- Mews fork: https://github.com/MewsSystems/blinkid-flutter (needs reset to v8)
- Current kiosk scanning: `kiosk/lib/features/scanning/data/blinkid_scanner.dart` (new file on branch `GX-blinkid-v8-stage1`)
- Current kiosk scanner dialog: `kiosk/lib/features/scanning/widgets/document_scanner_dialog.dart`
- v6 Android PlatformView reference (in old fork): `MicroblinkScannerView.kt`, `MicroblinkScannerViewFactory.kt`
- v6 iOS PlatformView reference (in old fork): `MicroblinkScannerView.swift`, `MicroblinkScannerViewFactory.swift`

---

## Effort Estimate

| Task | Est. |
|---|---|
| Reset Mews fork to v8, wire git dep in pubspec | 0.5d |
| Android: CameraX PlatformView + session frame loop + event channel | 3d |
| iOS: AVFoundation PlatformView + session frame loop + event channel | 4d |
| Dart: `BlinkIdScannerController`, `BlinkIdGuidance`, `BlinkIdScannerView` | 2d |
| Kiosk: feature flag + Flutter overlay UI (strings, animations) | 2d |
| Tests + QA on both platforms | 2d |
| **Total** | **~2 weeks** |

Android first (easier — v6 fork has CameraX shape to reference). iOS second.
