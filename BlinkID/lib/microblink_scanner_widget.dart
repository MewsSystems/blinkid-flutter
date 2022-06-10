import 'dart:convert';

import 'package:blinkid_flutter/microblink_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef MicroblinkScannerResultCallback = void Function(
  List<RecognizerResult>?,
);

class MicroblinkScannerWidget extends StatefulWidget {
  const MicroblinkScannerWidget({
    Key? key,
    required this.collection,
    required this.settings,
    required this.licenseKey,
    required this.onResult,
    required this.onError,
    required this.onFirstSideScanned,
    required this.onDetectionStatusUpdate,
    required this.mirrorAndroidFrontCameraPreview,
  }) : super(key: key);

  final RecognizerCollection collection;
  final OverlaySettings settings;
  final String licenseKey;
  final MicroblinkScannerResultCallback onResult;
  final ValueChanged<String> onError;
  final VoidCallback onFirstSideScanned;
  final ValueChanged<DetectionStatus> onDetectionStatusUpdate;
  final bool mirrorAndroidFrontCameraPreview;

  @override
  State<MicroblinkScannerWidget> createState() => _MicroblinkScannerWidgetState();
}

class _MicroblinkScannerWidgetState extends State<MicroblinkScannerWidget> {
  late MethodChannel channel;

  void _onFinishScanning(MethodCall call) {
    final List? jsonResults = jsonDecode(call.arguments);

    if (jsonResults == null) {
      widget.onResult(null);

      return;
    }

    List<RecognizerResult> results = [];

    for (var i = 0; i < jsonResults.length; i++) {
      final map = Map<String, dynamic>.from(jsonResults[i]);
      final data = widget.collection.recognizerArray[i].createResultFromNative(map);
      if (data.resultState != RecognizerResultState.empty) {
        results.add(data);
      }
    }

    widget.onResult(results);
  }

  void _onDetectionStatusUpdate(MethodCall call) {
    final Map<String, dynamic> json = jsonDecode(call.arguments);
    final detectionStatusUpdate = DetectionStatusUpdate.fromJson(json);
    widget.onDetectionStatusUpdate(detectionStatusUpdate.detectionStatus);
  }

  void _createChannel(int viewId) {
    channel = MethodChannel('MicroblinkScannerWidget/$viewId')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onFinishScanning') {
          _onFinishScanning(call);
        } else if (call.method == 'onClose') {
          widget.onResult(null);
        } else if (call.method == 'onFirstSideScanned') {
          widget.onFirstSideScanned();
        } else if (call.method == 'onError') {
          widget.onError(call.arguments as String);
        } else if (call.method == 'onDetectionStatusUpdate') {
          _onDetectionStatusUpdate(call);
        } else {
          throw PlatformException(
            code: 'Unsupported',
            details: 'Unsupported method ${call.method}',
          );
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'MicroblinkScannerView';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'recognizerCollection': widget.collection.toJson(),
      'licenseKey': widget.licenseKey,
      'overlaySettings': widget.settings.toJson(),
      if (defaultTargetPlatform == TargetPlatform.android)
        'mirrorFrontCameraPreview': widget.mirrorAndroidFrontCameraPreview
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _createChannel,
        );
      case TargetPlatform.android:
        return AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _createChannel,
        );
      default:
        throw UnsupportedError('$viewType platform view is not supported on ${defaultTargetPlatform.name}.');
    }
  }
}
