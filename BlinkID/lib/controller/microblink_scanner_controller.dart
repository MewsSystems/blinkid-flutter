import 'dart:convert';

import 'package:blinkid_flutter/recognizer.dart';
import 'package:blinkid_flutter/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MicroblinkScannerController with ChangeNotifier {
  @protected
  MicroblinkScannerController(int viewId, RecognizerCollection collection)
      : _collection = collection,
        _statusEventChannel = EventChannel('MicroblinkScannerWidget/$viewId/events/status'),
        _resultsEventChannel = EventChannel('MicroblinkScannerWidget/$viewId/events/scan'),
        _errorEventChannel = EventChannel('MicroblinkScannerWidget/$viewId/events/error'),
        _methodChannel = MethodChannel('MicroblinkScannerWidget/$viewId/method') {
    _methodChannel.setMethodCallHandler(_handleMethod);
  }

  final MethodChannel _methodChannel;
  final EventChannel _statusEventChannel;
  final EventChannel _resultsEventChannel;
  final EventChannel _errorEventChannel;

  final RecognizerCollection _collection;

  bool _firstSideScanned = false;
  bool get firstSideScanned => _firstSideScanned;

  /// Pause scanning without dismissing the camera view. If there is camera frame being processed at a time, the
  /// processing will finish, but the results of processing will not be returned.
  void pauseScanning() => _methodChannel.invokeMethod<void>('pauseScanning');

  /// Resumes scanning. The internal state of the scanner will not be reset.
  ///
  /// Use [resetState] to reset the internal state of the scanner.
  void resumeScanningAndResetState([bool resetState = true]) =>
      _methodChannel.invokeMethod<void>('resumeScanningAndResetState', resetState);

  void resetState() {
    _methodChannel.invokeMethod('resetState');
    _firstSideScanned = false;
    notifyListeners();
  }

  Future<bool> isScanningPaused() async => (await _methodChannel.invokeMethod<bool>('isScanningPaused')) ?? false;

  Stream<DetectionStatus> get detectionStatus => _statusEventChannel.receiveBroadcastStream().map((event) {
        final Map<String, dynamic> json = jsonDecode(event);
        return DetectionStatusUpdate.fromJson(json).detectionStatus;
      });

  Stream<List<RecognizerResult>> get results => _resultsEventChannel.receiveBroadcastStream().map((event) {
        final List jsonResults = jsonDecode(event);

        List<RecognizerResult> results = [];

        for (var i = 0; i < jsonResults.length; i++) {
          final map = Map<String, dynamic>.from(jsonResults[i]);
          final data = _collection.recognizerArray[i].createResultFromNative(map);
          if (data.resultState != RecognizerResultState.empty) {
            results.add(data);
          }
        }

        return results;
      });

  void _handleOnFirstSideScanned() {
    _firstSideScanned = true;
    notifyListeners();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onFirstSideScanned':
        return _handleOnFirstSideScanned();
      case 'onFinishScanning':
        // _onFinishScanning(call);
        break;
      case 'onClose':
        // _onClose(call);
        break;
      case 'onDetectionStatusUpdate':
        // _onDetectionStatusUpdate(call);
        break;
      case 'onError':
        // _onError(call);
        break;
      default:
        return PlatformException(code: 'Unsupported', details: 'Unsupported method ${call.method}');
    }
  }
}
