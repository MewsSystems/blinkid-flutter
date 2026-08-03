import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../blinkid_flutter_platform_interface.dart';
import '../blinkid_result.dart';
import '../blinkid_settings.dart';
import 'blinkid_guidance.dart';

enum BlinkIdScannerStatus {
  uninitialized,

  /// SDK resources are downloading / license is being verified.
  loadingSdk,

  /// SDK loaded; platform view not yet attached.
  initializing,

  ready,
  scanning,

  /// [DocumentScanned] fired natively; awaiting result serialization and
  /// transfer. Transient — lasts milliseconds.
  processing,

  /// Result delivered. Transient — callers typically show a brief success UI
  /// then pop the screen.
  done,

  error,
}

enum BlinkIdScanPhase {
  /// Scanning the front side.
  front,

  /// Front side complete. Show a flip animation, then call
  /// [BlinkIdScannerController.onFlipComplete] when the animation finishes so
  /// native scanning resumes. The phase remains [flip] until the camera
  /// produces its first frame after resuming — i.e. until the user has
  /// physically flipped the document. Failing to call [onFlipComplete] leaves
  /// the scanner paused indefinitely.
  ///
  /// Guidance events are suppressed during this phase; use [phase] instead.
  flip,

  /// User flipped the document; scanning the back side.
  back,
}

class BlinkIdScannerController extends ChangeNotifier {
  BlinkIdScannerStatus _status = BlinkIdScannerStatus.uninitialized;
  BlinkIdScannerStatus get status => _status;

  BlinkIdScanPhase _phase = BlinkIdScanPhase.front;
  BlinkIdScanPhase get phase => _phase;

  /// The last error set when [status] is [BlinkIdScannerStatus.error].
  /// Call [reset] to recover — the controller is reusable after an error.
  Exception? _lastError;
  Exception? get lastError => _lastError;

  final _guidanceController = StreamController<BlinkIdGuidance>.broadcast();

  /// Guidance events emitted during scanning. Events are suppressed while
  /// [phase] is [BlinkIdScanPhase.flip]; use [phase] to drive flip UI instead.
  /// [BlinkIdGuidanceFlipDocument] is never emitted here — it drives the
  /// phase transition internally.
  Stream<BlinkIdGuidance> get guidanceStream => _guidanceController.stream;

  MethodChannel? _methodChannel;
  StreamSubscription<dynamic>? _guidanceSub;
  Completer<BlinkIdScanningResult>? _scanCompleter;
  bool _debugLoggingEnabled = false;

  // True between onFlipComplete() and the first guidance event after resume.
  bool _awaitingBackSide = false;

  Map<String, dynamic> _creationParams = {};

  /// Internal: creation params forwarded to the native platform view.
  @internal
  Map<String, dynamic> get creationParams => _creationParams;

  /// Loads the BlinkID SDK (model download + license check) then prepares
  /// the controller for view attachment. Transitions to
  /// [BlinkIdScannerStatus.loadingSdk] during init so callers can render a
  /// loading indicator, then to [BlinkIdScannerStatus.initializing] once the
  /// SDK is ready and the platform view can be mounted.
  ///
  /// No-op if called more than once.
  Future<void> initialize(
    BlinkIdSdkSettings sdkSettings,
    BlinkIdSessionSettings sessionSettings,
  ) async {
    if (_status != BlinkIdScannerStatus.uninitialized) return;
    _setStatus(BlinkIdScannerStatus.loadingSdk);
    try {
      await BlinkIdFlutterPlatform.instance.loadBlinkIdSdk(sdkSettings);
    } on PlatformException catch (e) {
      _failScan(e.message ?? 'SDK load failed');
      rethrow;
    }
    _setStatus(BlinkIdScannerStatus.initializing);
    _creationParams = {
      'sdkSettings': sdkSettings.toJson(),
      'sessionSettings': sessionSettings.toJson(),
    };
  }

  /// Called by [BlinkIdScannerView] once the platform view is attached.
  /// Do not call this directly.
  @internal
  void onPlatformViewCreated(int id) {
    final methodChannel = MethodChannel(
      'com.microblink.blinkid.flutter/scanner/$id',
    );
    final eventChannel = EventChannel(
      'com.microblink.blinkid.flutter/scanner/$id/guidance',
    );

    methodChannel.setMethodCallHandler(_handleMethodCall);
    _methodChannel = methodChannel;
    _guidanceSub = eventChannel.receiveBroadcastStream().listen(
      _onGuidanceEvent,
      onError: (Object e) {
        _guidanceController.addError(e);
        _failScan('Camera stream error: $e');
      },
    );

    if (_debugLoggingEnabled) {
      methodChannel.invokeMethod<void>('setDebugLogging', true).ignore();
    }

    _setStatus(BlinkIdScannerStatus.ready);
  }

  void _onGuidanceEvent(dynamic event) {
    if (event is! String) return;
    final guidance = BlinkIdGuidance.fromString(event);

    switch (guidance) {
      case BlinkIdGuidanceFlipDocument():
        if (_phase == BlinkIdScanPhase.front) {
          _phase = BlinkIdScanPhase.flip;
          notifyListeners();
        }
        // Never emitted to guidanceStream; callers use phase instead.
        return;
      default:
        break;
    }

    // First event after resumeAfterFlip — user has flipped; go to back phase.
    if (_awaitingBackSide) {
      _awaitingBackSide = false;
      _phase = BlinkIdScanPhase.back;
      notifyListeners();
    }

    if (_phase == BlinkIdScanPhase.flip) return;

    _guidanceController.add(guidance);
  }

  /// Resumes back-side scanning after the flip animation completes.
  ///
  /// **You must call this** after showing your flip animation; failure to do so
  /// leaves the scanner paused indefinitely. [phase] transitions from [flip]
  /// to [back] automatically once the camera produces its first frame, i.e.
  /// once the user has physically flipped the document.
  void onFlipComplete() {
    if (_phase != BlinkIdScanPhase.flip) return;
    _awaitingBackSide = true;
    _methodChannel?.invokeMethod<void>('resumeAfterFlip').ignore();
  }

  /// Enables or disables native debug log forwarding to [debugPrint].
  ///
  /// When enabled, key lifecycle events (scan start, side scanned, errors) are
  /// forwarded from native via the method channel and printed with `[BlinkID]`
  /// prefix. Disabled by default — no channel traffic is incurred unless opted in.
  /// Safe to call before or after the platform view is created.
  void setDebugLogging(bool enabled) {
    _debugLoggingEnabled = enabled;
    _methodChannel?.invokeMethod<void>('setDebugLogging', enabled).ignore();
  }

  /// Starts a scan session and returns the [BlinkIdScanningResult] on success.
  ///
  /// If the controller is still initializing (status [BlinkIdScannerStatus.loadingSdk]
  /// or [BlinkIdScannerStatus.initializing]), this call suspends and resumes
  /// automatically once the platform view is ready — so calling immediately
  /// after [initialize] is safe without an explicit status check.
  ///
  /// Throws [BlinkIdScanCancelException] on cancel, [BlinkIdScanResetException]
  /// on [reset], or [StateError] if [initialize] was never called.
  Future<BlinkIdScanningResult> scan() async {
    switch (_status) {
      case BlinkIdScannerStatus.loadingSdk ||
          BlinkIdScannerStatus.initializing:
        await _awaitReady();
      case BlinkIdScannerStatus.ready:
        break;
      default:
        throw StateError('Controller not ready (status: $_status)');
    }

    final channel = _methodChannel;
    if (channel == null) throw StateError('Platform view not yet created');

    _phase = BlinkIdScanPhase.front;
    _setStatus(BlinkIdScannerStatus.scanning);
    _scanCompleter = Completer<BlinkIdScanningResult>();

    try {
      await channel.invokeMethod<void>('startScan');
    } on PlatformException catch (e) {
      _failScan(e.message ?? 'startScan failed');
      rethrow;
    }

    return _scanCompleter!.future;
  }

  /// Cancels the current scan and returns to [BlinkIdScannerStatus.ready].
  /// The [Future] from [scan] completes with [BlinkIdScanCancelException].
  void cancel() {
    _methodChannel?.invokeMethod<void>('cancelScan');
    switch (_status) {
      case BlinkIdScannerStatus.scanning || BlinkIdScannerStatus.processing:
        _abortWithCancel();
      default:
        break;
    }
  }

  /// Cancels any in-flight scan and returns the controller to
  /// [BlinkIdScannerStatus.ready], ready for a new [scan] call. Use this to
  /// implement retry flows (e.g. after a timeout).
  ///
  /// The [Future] from [scan] completes with [BlinkIdScanResetException].
  ///
  /// Can also be called when [status] is [BlinkIdScannerStatus.error] to
  /// recover and allow a new scan.
  void reset() {
    _methodChannel?.invokeMethod<void>('cancelScan');
    _phase = BlinkIdScanPhase.front;
    _awaitingBackSide = false;
    _lastError = null;
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.completeError(const BlinkIdScanResetException());
    switch (_status) {
      case BlinkIdScannerStatus.uninitialized ||
          BlinkIdScannerStatus.loadingSdk ||
          BlinkIdScannerStatus.initializing:
        break;
      default:
        _setStatus(BlinkIdScannerStatus.ready);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onDebugLog':
          debugPrint('[BlinkID] ${call.arguments}');
        case 'onDocumentScanned':
          _setStatus(BlinkIdScannerStatus.processing);
        case 'onScanResult':
          _completeScan(_parseResult(call.arguments));
        case 'onScanError':
          _failScan(call.arguments as String? ?? 'Scan error');
        case 'onScanCanceled':
          _abortWithCancel();
      }
    } catch (e, st) {
      debugPrint('BlinkID _handleMethodCall error (${call.method}): $e\n$st');
      _failScan('Handler error: $e');
    }
  }

  BlinkIdScanningResult _parseResult(dynamic rawArgs) {
    final Map<String, dynamic> json = switch (rawArgs) {
      final Map m => Map<String, dynamic>.from(m),
      final String s => Map<String, dynamic>.from(jsonDecode(s) as Map),
      _ => throw ArgumentError(
          'Unexpected scan result type: ${rawArgs?.runtimeType}',
        ),
    };
    return BlinkIdScanningResult(json);
  }

  Future<void> _awaitReady() {
    if (_status == BlinkIdScannerStatus.ready) return Future.value();
    final completer = Completer<void>();
    void listener() {
      switch (_status) {
        case BlinkIdScannerStatus.ready:
          removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        case BlinkIdScannerStatus.error:
          removeListener(listener);
          if (!completer.isCompleted) {
            completer.completeError(
              _lastError ?? Exception('Controller initialization failed'),
            );
          }
        default:
          break;
      }
    }
    addListener(listener);
    return completer.future;
  }

  void _completeScan(BlinkIdScanningResult result) {
    _setStatus(BlinkIdScannerStatus.done);
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.complete(result);
  }

  void _abortWithCancel() {
    _setStatus(BlinkIdScannerStatus.ready);
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.completeError(const BlinkIdScanCancelException());
  }

  void _failScan(String message) {
    final error = Exception(message);
    _lastError = error;
    _setStatus(BlinkIdScannerStatus.error);
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.completeError(error);
  }

  void _setStatus(BlinkIdScannerStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _guidanceSub?.cancel();
    _guidanceController.close();
    _methodChannel?.invokeMethod<void>('dispose').ignore();
    // Drain in-flight scan without corrupting status — widget tree tearing down.
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.completeError(const BlinkIdScanDisposeException());
    super.dispose();
  }
}

/// Thrown when the user explicitly cancels scanning via
/// [BlinkIdScannerController.cancel].
class BlinkIdScanCancelException implements Exception {
  const BlinkIdScanCancelException();
  @override
  String toString() => 'Scan canceled';
}

/// Thrown when [BlinkIdScannerController.reset] is called while a scan is in
/// progress. Distinct from a user-initiated cancel so callers can branch on
/// retry vs. dismiss.
class BlinkIdScanResetException implements Exception {
  const BlinkIdScanResetException();
  @override
  String toString() => 'Scan reset';
}

/// Thrown when the controller is [dispose]d while a scan is in progress.
class BlinkIdScanDisposeException implements Exception {
  const BlinkIdScanDisposeException();
  @override
  String toString() => 'Scanner disposed';
}
