import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'package:flutter/material.dart';

import 'custom_scanner_screen.dart';

const _licenseKeyAndroid = String.fromEnvironment('BLINKID_LICENSE_KEY_ANDROID');
const _licenseKeyIos = String.fromEnvironment('BLINKID_LICENSE_KEY_IOS');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _blinkId = BlinkIdFlutter();
  String _result = '';
  bool _scanning = false;

  BlinkIdSdkSettings get _sdkSettings => BlinkIdSdkSettings(
    licenseKey: switch (Theme.of(context).platform) {
      .iOS => _licenseKeyIos,
      .android => _licenseKeyAndroid,
      .fuchsia || .linux || .macOS || .windows => throw UnsupportedError('BlinkID not supported on this platform'),
    },
  );

  BlinkIdSessionSettings get _sessionSettings => BlinkIdSessionSettings(scanningSettings: BlinkIdScanningSettings());

  Future<void> _performScan() async {
    setState(() {
      _scanning = true;
      _result = '';
    });
    try {
      final result = await _blinkId.performScan(
        blinkIdSdkSettings: _sdkSettings,
        blinkIdSessionSettings: _sessionSettings,
      );
      setState(() {
        _result = _formatResult(result);
      });
    } catch (e, st) {
      debugPrint('BlinkID scan error: $e\n$st');
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _scanning = false;
      });
    }
  }

  Future<void> _openCustomScanner() async {
    final result = await Navigator.push<BlinkIdScanningResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomScannerScreen(sdkSettings: _sdkSettings, sessionSettings: _sessionSettings),
      ),
    );
    if (result != null) {
      setState(() {
        _result = _formatResult(result);
      });
    }
  }

  String _formatResult(BlinkIdScanningResult? result) {
    if (result == null) return 'No result';
    final firstName = result.firstName?.value ?? '';
    final lastName = result.lastName?.value ?? '';
    final dob = result.dateOfBirth?.date?.toString() ?? '';
    return 'Name: $firstName $lastName\nDOB: $dob';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BlinkID Example')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(onPressed: _scanning ? null : _performScan, child: const Text('Scan (Native UI)')),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _scanning ? null : _openCustomScanner, child: const Text('Scan (Custom UI)')),
          const SizedBox(height: 24),
          if (_scanning) const Center(child: CircularProgressIndicator()),
          if (_result.isNotEmpty)
            Card(
              child: Padding(padding: const EdgeInsets.all(16), child: Text(_result)),
            ),
        ],
      ),
    ),
  );
}
