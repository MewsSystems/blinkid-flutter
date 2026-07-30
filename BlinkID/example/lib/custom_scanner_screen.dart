import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'package:flutter/material.dart';

class CustomScannerScreen extends StatefulWidget {
  const CustomScannerScreen({
    required this.sdkSettings,
    required this.sessionSettings,
    super.key,
  });

  final BlinkIdSdkSettings sdkSettings;
  final BlinkIdSessionSettings sessionSettings;

  @override
  State<CustomScannerScreen> createState() => _CustomScannerScreenState();
}

class _CustomScannerScreenState extends State<CustomScannerScreen> {
  late final BlinkIdScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BlinkIdScannerController();
    _controller
        .initialize(widget.sdkSettings, widget.sessionSettings)
        .then((_) => _controller.scan())
        .then((result) {
          if (mounted) Navigator.pop(context, result);
        })
        .catchError((e) {
          if (mounted) Navigator.pop(context, null);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        BlinkIdScannerView(controller: _controller),
        _GuidanceOverlay(controller: _controller),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              _controller.cancel();
              Navigator.pop(context, null);
            },
          ),
        ),
      ],
    ),
  );
}

class _GuidanceOverlay extends StatelessWidget {
  const _GuidanceOverlay({required this.controller});

  final BlinkIdScannerController controller;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 48,
      ),
      child: StreamBuilder<BlinkIdGuidance>(
        stream: controller.guidanceStream,
        builder: (context, snapshot) {
          final text = _guidanceText(snapshot.data);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(text),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    ),
  );

  String _guidanceText(BlinkIdGuidance? guidance) => switch (guidance) {
    null || BlinkIdGuidanceSearching() => 'Point camera at your ID',
    BlinkIdGuidanceTooFar() => 'Move closer',
    BlinkIdGuidanceTooClose() => 'Move further away',
    BlinkIdGuidanceTilted() => 'Hold the document straight',
    BlinkIdGuidanceHoldStill() => 'Hold still...',
    BlinkIdGuidanceFlipDocument() => 'Flip your document',
  };
}
