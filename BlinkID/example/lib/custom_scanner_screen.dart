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
        .catchError((Object e) {
          if (!mounted) return;
          if (e.toString() != 'Scan canceled') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scan error: $e')),
            );
          }
          Navigator.pop(context, null);
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
        BlinkIdScannerView(
          controller: _controller,
          placeholderBuilder: (_) => const ColoredBox(
            color: Color(0xFF000000),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFFFFF)),
            ),
          ),
          errorBuilder: (_, error) => ColoredBox(
            color: const Color(0xFF000000),
            child: Center(
              child: Text(
                'Camera error:\n$error',
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => switch (_controller.phase) {
            BlinkIdScanPhase.flip => _FlipOverlay(controller: _controller),
            _ => _GuidanceOverlay(controller: _controller),
          },
        ),
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

// Shown during flip phase — persistent, blocks other guidance.
class _FlipOverlay extends StatefulWidget {
  const _FlipOverlay({required this.controller});
  final BlinkIdScannerController controller;

  @override
  State<_FlipOverlay> createState() => _FlipOverlayState();
}

class _FlipOverlayState extends State<_FlipOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim.forward().then((_) {
      // Animation done → tell controller to resume back-side scanning.
      widget.controller.onFlipComplete();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context, _) => Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(_anim.value * 3.14159),
              child: const Icon(Icons.credit_card, color: Colors.white, size: 80),
            ),
            const SizedBox(height: 24),
            const Text(
              'Flip to the back side',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Shown during front/back scanning phases.
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
          final text = _guidanceText(snapshot.data, controller.phase);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(text),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  String _guidanceText(BlinkIdGuidance? guidance, BlinkIdScanPhase phase) {
    final prefix = phase == BlinkIdScanPhase.back ? 'Back side: ' : '';
    return prefix + switch (guidance) {
      null || BlinkIdGuidanceSearching() =>
        phase == BlinkIdScanPhase.back
          ? 'Scan the back side of a document'
          : 'Scan the front side of a document',
      BlinkIdGuidanceTooFar() => 'Move closer',
      BlinkIdGuidanceTooClose() => 'Move further away',
      BlinkIdGuidanceTooCloseToEdge() => 'Move the document from the edge',
      BlinkIdGuidanceTilted() => 'Keep document parallel to phone',
      BlinkIdGuidanceHoldStill() => 'Hold still…',
      BlinkIdGuidanceFlipDocument() => 'Flip to the back side',
      BlinkIdGuidanceBlur() => 'Keep document and phone still',
      BlinkIdGuidanceGlare() => 'Tilt or move document to remove reflection',
      BlinkIdGuidanceNotFullyVisible() => 'Keep the document fully visible',
      BlinkIdGuidanceLowLight() => 'Move to a brighter spot',
      BlinkIdGuidanceTooMuchLight() => 'Move to a spot with less lighting',
    };
  }
}
