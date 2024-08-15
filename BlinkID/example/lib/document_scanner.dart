import 'package:blinkid_flutter/microblink_scanner.dart';
import 'package:blinkid_flutter/microblink_scanner_widget.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

typedef MicroblinkScannerResultCallback = Future<bool> Function(List<RecognizerResult>?);

typedef MicroblinkRecognizerResult = List<RecognizerResult>;

extension ScanDocumentExtension on BuildContext {
  Future<MicroblinkRecognizerResult?> scanDocument() async {
    final permissions = await [Permission.camera].request();

    if (permissions.values.any((status) => status.isDenied)) {
      ScaffoldMessenger.of(this)
          .showSnackBar(const SnackBar(content: Text('Permissions are required to scan documents.')));
    }

    return showDialog(
      context: this,
      builder: (_) => const _DocumentScannerDialog(),
    );
  }
}

class _DocumentScannerDialog extends StatefulWidget {
  const _DocumentScannerDialog();

  @override
  State<_DocumentScannerDialog> createState() => _DocumentScannerDialogState();
}

class _DocumentScannerDialogState extends State<_DocumentScannerDialog> {
  final ValueNotifier<bool> _firstSideScannedNotifier = ValueNotifier(false);
  final ValueNotifier<DetectionStatus?> _detectionStatusNotifier = ValueNotifier(null);
  MicroblinkRecognizerResult? _result;

  static const _shadows = [
    Shadow(blurRadius: 60),
    Shadow(blurRadius: 40),
    Shadow(blurRadius: 20),
    Shadow(blurRadius: 10)
  ];

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _DocumentScanner(
                    recognizerCollection: RecognizerCollection(<Recognizer>[
                      BlinkIdMultiSideRecognizer()
                        ..recognitionModeFilter = (RecognitionModeFilter()..enablePhotoId = false)
                        ..skipUnsupportedBack = true
                        ..anonymizationMode = AnonymizationMode.None,
                    ]),
                    onResult: (result) {
                      if (_result != null) return Future.value(false);
                      _result = result;

                      Navigator.of(context).pop(_result);
                      return Future.value(false);
                    },
                    onFirstSideScanned: () => _firstSideScannedNotifier.value = true,
                    onDetectionStatusUpdate: (status) => _detectionStatusNotifier.value = status,
                    useFrontCamera: false,
                    flipFrontCamera: false),
              ),
              Positioned(
                  left: 40,
                  right: 40,
                  top: 40,
                  child: Column(
                    children: [
                      ValueListenableBuilder(
                          valueListenable: _firstSideScannedNotifier,
                          builder: (_, firstSideScanned, __) => Text(
                                firstSideScanned ? 'Scan the back of the document.' : 'Scan the front of the document.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(color: Colors.white, shadows: _shadows),
                              )),
                      const SizedBox(height: 20),
                      ValueListenableBuilder(
                          valueListenable: _detectionStatusNotifier,
                          builder: (_, detectionStatus, __) => Text(
                                detectionStatus?.directions ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white, shadows: _shadows),
                              )),
                    ],
                  )),
              Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                      padding: const EdgeInsets.all(40),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        shadows: _shadows,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(null))),
            ],
          ),
        ),
      );
}

class _DocumentScanner extends StatelessWidget {
  const _DocumentScanner({
    required this.recognizerCollection,
    required this.onResult,
    required this.onFirstSideScanned,
    required this.onDetectionStatusUpdate,
    required this.useFrontCamera,
    required this.flipFrontCamera,
  });

  final RecognizerCollection recognizerCollection;
  final MicroblinkScannerResultCallback onResult;
  final VoidCallback onFirstSideScanned;
  final ValueSetter<DetectionStatus> onDetectionStatusUpdate;
  final bool useFrontCamera;
  final bool flipFrontCamera;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: MicroblinkScannerWidget(
        collection: recognizerCollection,
        settings: DocumentVerificationOverlaySettings()
          ..useFrontCamera = useFrontCamera
          ..flipFrontCamera = flipFrontCamera,
        licenseKey: Theme.of(context).platform.microblinkLicenseKey,
        onScanDone: (scanResultState) {},
        onResult: onResult,
        onError: print,
        onFirstSideScanned: onFirstSideScanned,
        onDetectionUpdate: (update) => onDetectionStatusUpdate(update.detectionStatus),
      ),
    );
  }
}

extension on DetectionStatus {
  String get directions => switch (this) {
        DetectionStatus.Failed => 'No document detected.',
        DetectionStatus.CameraAngleTooSteep => 'Adjust the camera angle.',
        DetectionStatus.CameraTooClose => 'Move the camera further away.',
        DetectionStatus.CameraTooFar => 'Move the camera closer.',
        DetectionStatus.DocumentPartiallyVisible => 'Document is partially visible.',
        DetectionStatus.DocumentTooCloseToCameraEdge => 'Move the document away from the edge.',
        DetectionStatus.Success => 'Document detected.',
        DetectionStatus.FallbackSuccess => 'Fallback success.',
      };
}

extension on TargetPlatform {
  String get microblinkLicenseKey => switch (this) {
        TargetPlatform.iOS =>
          "sRwCABVjb20ubWljcm9ibGluay5zYW1wbGUBbGV5SkRjbVZoZEdWa1QyNGlPakUzTWpFek9EVTRNVEEyTlRFc0lrTnlaV0YwWldSR2IzSWlPaUprWkdRd05qWmxaaTAxT0RJekxUUXdNRGd0T1RRNE1DMDFORFU0WWpBeFlUVTJZamdpZlE9PWEJrlgmmQ9VywX915J8m1TjF2GrO750y/ksBB6HA6EHBHcRe3cQ6hS2IL6rSnxw2rb3foQSv3L7LxjTiJiKtO23Rb5a3xHvNoe7A8BlX7iCT39OB48Cx8pkDmRFQ/vgwDrO6j4GqNCP8u//M0fMoE9XG2nI9PVY",
        TargetPlatform.android =>
          'sRwCABVjb20ubWljcm9ibGluay5zYW1wbGUAbGV5SkRjbVZoZEdWa1QyNGlPakUzTWpFek9EVTNOak0xTmpRc0lrTnlaV0YwWldSR2IzSWlPaUprWkdRd05qWmxaaTAxT0RJekxUUXdNRGd0T1RRNE1DMDFORFU0WWpBeFlUVTJZamdpZlE9PWKzGRpwZ0Yg81/n2kQ09RrtiQhs5K8k+Mjawaer1MOcxgeLaIhkBn5CpPi4cbtqTdTj9h7vrE6cxFRbrqpYyfoIAAFut1hI/f7zN3CFouAebHnqS38/Ocwk8xIafUumdpdtpBtU1er+p6Z+CeUnzr6c84A9xjxK',
        _ => throw UnsupportedError('Unsupported platform $this')
      };
}
