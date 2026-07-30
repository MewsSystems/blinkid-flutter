import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../blinkid_result.dart';
import '../blinkid_settings.dart';
import 'blinkid_guidance.dart';

enum BlinkIdScannerStatus {
  uninitialized,
  initializing,
  ready,
  scanning,
  done,
  error,
}

class BlinkIdScannerController extends ChangeNotifier {
  BlinkIdScannerStatus _status = BlinkIdScannerStatus.uninitialized;
  BlinkIdScannerStatus get status => _status;

  final _guidanceController = StreamController<BlinkIdGuidance>.broadcast();
  Stream<BlinkIdGuidance> get guidanceStream => _guidanceController.stream;

  MethodChannel? _methodChannel;
  EventChannel? _eventChannel;
  StreamSubscription<dynamic>? _guidanceSub;
  Completer<BlinkIdScanningResult>? _scanCompleter;

  Map<String, dynamic> _creationParams = {};
  Map<String, dynamic> get creationParams => _creationParams;

  Future<void> initialize(
    BlinkIdSdkSettings sdkSettings,
    BlinkIdSessionSettings sessionSettings,
  ) async {
    if (_status != BlinkIdScannerStatus.uninitialized) return;
    _setStatus(BlinkIdScannerStatus.initializing);
    _creationParams = {
      'sdkSettings': sdkSettings.toJson(),
      'sessionSettings': sessionSettings.toJson(),
    };
    // Channels assigned after platform view creation via onPlatformViewCreated.
  }

  void onPlatformViewCreated(int id) {
    _methodChannel = MethodChannel(
      'com.microblink.blinkid.flutter/scanner/$id',
    );
    _eventChannel = EventChannel(
      'com.microblink.blinkid.flutter/scanner/$id/guidance',
    );

    _methodChannel!.setMethodCallHandler(_handleMethodCall);

    _guidanceSub = _eventChannel!.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          _guidanceController.add(BlinkIdGuidance.fromString(event));
        }
      },
      onError: (Object e) {
        _guidanceController.addError(e);
        _failScan('Camera stream error: $e');
      },
    );

    _setStatus(BlinkIdScannerStatus.ready);
  }

  Future<BlinkIdScanningResult> scan() async {
    if (_status != BlinkIdScannerStatus.ready) {
      throw StateError('Controller not ready (status: $_status)');
    }
    final channel = _methodChannel;
    if (channel == null) {
      throw StateError('Platform view not yet created');
    }

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

  void cancel() {
    _methodChannel?.invokeMethod<void>('cancelScan');
    if (_status == BlinkIdScannerStatus.scanning) {
      _setStatus(BlinkIdScannerStatus.ready);
      _scanCompleter?.completeError(const _CancelException());
      _scanCompleter = null;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScanResult':
        final json = Map<String, dynamic>.from(call.arguments as Map);
        final result = BlinkIdScanningResult(json);
        _setStatus(BlinkIdScannerStatus.done);
        _scanCompleter?.complete(result);
        _scanCompleter = null;
      case 'onScanError':
        _failScan(call.arguments as String? ?? 'Scan error');
      case 'onScanCanceled':
        _setStatus(BlinkIdScannerStatus.ready);
        _scanCompleter?.completeError(const _CancelException());
        _scanCompleter = null;
    }
  }

  void _failScan(String message) {
    _setStatus(BlinkIdScannerStatus.error);
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.completeError(Exception(message));
  }

  void _setStatus(BlinkIdScannerStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _guidanceSub?.cancel();
    _guidanceController.close();
    // Best-effort cleanup; ignore errors during dispose.
    _methodChannel?.invokeMethod<void>('dispose').ignore();
    // Fail any pending scan so callers don't leak.
    _failScan('Controller disposed');
    super.dispose();
  }
}

class _CancelException implements Exception {
  const _CancelException();
  @override
  String toString() => 'Scan canceled';
}
