import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'blinkid_scanner_controller.dart';

class BlinkIdScannerView extends StatelessWidget {
  const BlinkIdScannerView({required this.controller, super.key});

  final BlinkIdScannerController controller;

  static const _viewType = 'com.microblink.blinkid/scanner_view';

  @override
  Widget build(BuildContext context) => switch (defaultTargetPlatform) {
    TargetPlatform.android => PlatformViewLink(
        viewType: _viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
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
          view.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
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
