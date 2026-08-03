import 'dart:async';
import 'dart:math' show pi;

import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'package:flutter/material.dart';

// Pure top-level function — no state, easily testable.
String guidanceText(BlinkIdGuidance? guidance, BlinkIdScanPhase phase) {
  final prefix = phase == BlinkIdScanPhase.back ? 'Back side: ' : '';
  return prefix +
      switch (guidance) {
        null || BlinkIdGuidanceSearching() =>
          phase == BlinkIdScanPhase.back ? 'Scan the back side of a document' : 'Scan the front side of a document',
        BlinkIdGuidanceTooFar() => 'Move closer',
        BlinkIdGuidanceTooClose() => 'Move further away',
        BlinkIdGuidanceTooCloseToEdge() => 'Move the document from the edge',
        BlinkIdGuidanceTilted() => 'Keep document parallel to phone',
        BlinkIdGuidanceHoldStill() => 'Hold still…',
        BlinkIdGuidanceFlipDocument() => 'Flip to the back side',
        BlinkIdGuidanceWrongSide() => 'Flip the document',
        BlinkIdGuidanceBlur() => 'Keep document and phone still',
        BlinkIdGuidanceGlare() => 'Tilt or move document to remove reflection',
        BlinkIdGuidanceNotFullyVisible() => 'Keep the document fully visible',
        BlinkIdGuidanceLowLight() => 'Move to a brighter spot',
        BlinkIdGuidanceTooMuchLight() => 'Move to a spot with less lighting',
      };
}

class CustomScannerScreen extends StatefulWidget {
  const CustomScannerScreen({required this.sdkSettings, required this.sessionSettings, super.key});

  final BlinkIdSdkSettings sdkSettings;
  final BlinkIdSessionSettings sessionSettings;

  @override
  State<CustomScannerScreen> createState() => _CustomScannerScreenState();
}

class _CustomScannerScreenState extends State<CustomScannerScreen> {
  late final BlinkIdScannerController _controller;
  StreamSubscription<BlinkIdGuidance>? _guidanceSub;
  bool _popping = false;
  bool _showingTimeoutDialog = false;
  BlinkIdScannerStatus _lastStatus = BlinkIdScannerStatus.uninitialized;
  BlinkIdScanPhase _lastPhase = BlinkIdScanPhase.front;
  Timer? _scanTimer;

  static const _timeoutSeconds = 10;

  void _safePop([BlinkIdScanningResult? result]) {
    _scanTimer?.cancel();
    if (_popping || !mounted) return;
    _popping = true;
    Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();
    _controller = BlinkIdScannerController();
    _controller.addListener(_onScanStateChanged);
    _guidanceSub = _controller.guidanceStream.listen(_onGuidanceForTimer);
    unawaited(_startScanning());
  }

  // Manages the per-side scan timer based on status/phase transitions.
  void _onScanStateChanged() {
    final status = _controller.status;
    final phase = _controller.phase;

    if (status != _lastStatus) {
      _lastStatus = status;
      if (status == BlinkIdScannerStatus.scanning) _startScanTimer();
    }

    if (phase != _lastPhase) {
      _lastPhase = phase;
      switch (phase) {
        case BlinkIdScanPhase.flip:
          _scanTimer?.cancel();
        case BlinkIdScanPhase.back:
          _startScanTimer();
        case BlinkIdScanPhase.front:
          break;
      }
    }
  }

  void _onGuidanceForTimer(BlinkIdGuidance guidance) {
    // Active detection resets the timeout. Searching = nothing visible;
    // wrongSide = can't proceed — neither counts as progress.
    if (guidance is BlinkIdGuidanceSearching || guidance is BlinkIdGuidanceWrongSide) return;
    if (_controller.status == BlinkIdScannerStatus.scanning) _startScanTimer();
  }

  void _startScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: _timeoutSeconds), () => unawaited(_onScanTimeout()));
  }

  Future<void> _onScanTimeout() async {
    if (!mounted || _showingTimeoutDialog) return;
    _showingTimeoutDialog = true;

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Couldn't read document"),
        content: const Text('Make sure the document is well-lit, fully visible, and not blurry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Try Again')),
        ],
      ),
    );

    _showingTimeoutDialog = false;
    if (!mounted) return;

    if (retry == true) {
      _lastPhase = BlinkIdScanPhase.front;
      _controller.reset(); // → BlinkIdScanResetException → _startScanning loop continues
    } else {
      _controller.cancel();
      _safePop();
    }
  }

  Future<void> _startScanning() async {
    try {
      await _controller.initialize(widget.sdkSettings, widget.sessionSettings);
    } catch (e, st) {
      debugPrint('BlinkID init error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
      _safePop();
      return;
    }

    // scan() suspends internally until the platform view is ready, then starts.
    // The loop continues on reset() so the user can retry without rebuilding.
    while (mounted) {
      try {
        final result = await _controller.scan();
        _scanTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 700));
        _safePop(result);
        return;
      } on BlinkIdScanCancelException {
        _scanTimer?.cancel();
        _safePop();
        return;
      } on BlinkIdScanResetException {
        _scanTimer?.cancel();
        // Controller is back to ready — loop restarts scan().
      } on BlinkIdScanDisposeException {
        _scanTimer?.cancel();
        return;
      } catch (e, st) {
        _scanTimer?.cancel();
        debugPrint('BlinkID scan error: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
        }
        _safePop();
        return;
      }
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _guidanceSub?.cancel();
    _controller.removeListener(_onScanStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.status;

        if (status == BlinkIdScannerStatus.uninitialized || status == BlinkIdScannerStatus.loadingSdk) {
          return const ColoredBox(
            color: Color(0xFF000000),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFFFFFFF))),
          );
        }

        if (status == BlinkIdScannerStatus.error) {
          return ColoredBox(
            color: const Color(0xFF000000),
            child: Center(
              child: Text(
                'Camera error:\n${_controller.lastError}',
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            BlinkIdScannerView(controller: _controller),
            if (status == BlinkIdScannerStatus.initializing)
              const ColoredBox(
                color: Color(0xFF000000),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFFFFFF))),
              ),
            if (status != BlinkIdScannerStatus.initializing &&
                status != BlinkIdScannerStatus.processing &&
                status != BlinkIdScannerStatus.done)
              switch (_controller.phase) {
                BlinkIdScanPhase.flip => _FlipOverlay(controller: _controller),
                _ => _GuidanceOverlay(controller: _controller),
              },
            if (status == BlinkIdScannerStatus.done) const _ScanSuccessOverlay(message: 'Document scanned!'),
            if (status != BlinkIdScannerStatus.processing && status != BlinkIdScannerStatus.done)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _controller.cancel();
                    _safePop();
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _FlipOverlay extends StatefulWidget {
  const _FlipOverlay({required this.controller});
  final BlinkIdScannerController controller;

  @override
  State<_FlipOverlay> createState() => _FlipOverlayState();
}

enum _FlipStage { success, animating, persistent }

class _FlipOverlayState extends State<_FlipOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  _FlipStage _stage = _FlipStage.success;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _stage = _FlipStage.animating);
      _anim.forward().then((_) {
        if (!mounted) return;
        // Resume native scanning. Phase stays 'flip' until the camera detects
        // the first back-side frame (_awaitingBackSide in controller).
        widget.controller.onFlipComplete();
        setState(() => _stage = _FlipStage.persistent);
      });
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _FlipStage.success => const _ScanSuccessOverlay(message: 'Front side scanned!'),
    _FlipStage.animating => AnimatedBuilder(animation: _anim, builder: (context, _) => _flipFrame(_anim.value)),
    _FlipStage.persistent => _flipFrame(0),
  };

  Widget _flipFrame(double t) => Container(
    color: Colors.black54,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(t * pi),
            child: const Icon(Icons.credit_card, color: Colors.white, size: 80),
          ),
          const SizedBox(height: 24),
          const Text(
            'Flip to the back side',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _ScanSuccessOverlay extends StatelessWidget {
  const _ScanSuccessOverlay({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black54,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 72),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _GuidanceOverlay extends StatefulWidget {
  const _GuidanceOverlay({required this.controller});
  final BlinkIdScannerController controller;

  @override
  State<_GuidanceOverlay> createState() => _GuidanceOverlayState();
}

class _GuidanceOverlayState extends State<_GuidanceOverlay> {
  int _switcherKey = 0;
  String _displayText = '';
  String? _pendingText;
  Timer? _debounce;
  Timer? _resetTimer;
  StreamSubscription<BlinkIdGuidance>? _sub;

  static const _resetDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _displayText = guidanceText(null, widget.controller.phase);
    _sub = widget.controller.guidanceStream.listen(_onGuidance);
  }

  void _onGuidance(BlinkIdGuidance g) {
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetDelay, _resetToDefault);

    final next = guidanceText(g, widget.controller.phase);
    // Already showing or already queued — let the running debounce finish.
    if (next == _displayText || next == _pendingText) return;

    _pendingText = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _displayText = _pendingText!;
        _pendingText = null;
        _switcherKey++;
      });
    });
  }

  void _resetToDefault() {
    _debounce?.cancel();
    _pendingText = null;
    final defaultText = guidanceText(null, widget.controller.phase);
    if (!mounted || _displayText == defaultText) return;
    setState(() {
      _displayText = defaultText;
      _switcherKey++;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _resetTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 48),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(_switcherKey),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: Text(
            _displayText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
