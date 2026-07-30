import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'blinkid_scanner_controller.dart';

typedef BlinkIdErrorBuilder = Widget Function(BuildContext context, Object error);
typedef BlinkIdPlaceholderBuilder = Widget Function(BuildContext context);

class BlinkIdScannerView extends StatelessWidget {
  const BlinkIdScannerView({
    required this.controller,
    this.errorBuilder,
    this.placeholderBuilder,
    super.key,
  });

  final BlinkIdScannerController controller;

  /// Shown when camera fails to start or a platform error occurs.
  /// Defaults to a black box if null.
  final BlinkIdErrorBuilder? errorBuilder;

  /// Shown while the camera is initialising (before first frame).
  /// Defaults to a black box if null.
  final BlinkIdPlaceholderBuilder? placeholderBuilder;

  static const _viewType = 'com.microblink.blinkid/scanner_view';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == BlinkIdScannerStatus.error) {
          final err = controller.lastError ?? Exception('Camera error');
          return errorBuilder?.call(context, err) ??
              const ColoredBox(color: Color(0xFF000000));
        }
        if (controller.status == BlinkIdScannerStatus.uninitialized ||
            controller.status == BlinkIdScannerStatus.initializing) {
          return placeholderBuilder?.call(context) ??
              const ColoredBox(color: Color(0xFF000000));
        }
        return _buildPlatformView(context);
      },
    );
  }

  Widget _buildPlatformView(BuildContext context) =>
      switch (defaultTargetPlatform) {
        TargetPlatform.android => PlatformViewLink(
            viewType: _viewType,
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers:
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            ),
            onCreatePlatformView: (params) {
              final view = PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: _viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: controller.creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              );
              view.addOnPlatformViewCreatedListener(
                params.onPlatformViewCreated,
              );
              view.addOnPlatformViewCreatedListener(
                controller.onPlatformViewCreated,
              );
              view.create();
              return view;
            },
          ),
        TargetPlatform.iOS => UiKitView(
            viewType: _viewType,
            creationParams: controller.creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: controller.onPlatformViewCreated,
          ),
        _ => throw UnsupportedError(
            'BlinkIdScannerView unsupported on $defaultTargetPlatform',
          ),
      };
}
