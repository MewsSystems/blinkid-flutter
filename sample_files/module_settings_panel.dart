import 'package:flutter/material.dart';
import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'scanning_modules_config.dart';

class ModuleSettingsPanel extends StatelessWidget {
  final ScanningModulesConfig config;
  final VoidCallback onChanged;

  const ModuleSettingsPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scanning modules',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Disabled modules are sent as null (not supported). '
          'Settings apply to all scan actions below.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<ScanningMode>(
            key: ValueKey('scanning-mode-${config.scanningMode}'),
            initialValue: config.scanningMode,
            decoration: InputDecoration(
              labelText: 'Scanning Mode',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: ScanningMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(mode.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                config.scanningMode = value;
                onChanged();
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        _BarcodeModuleCard(config: config, onChanged: onChanged),
        const SizedBox(height: 8),
        _DocumentCaptureModuleCard(config: config, onChanged: onChanged),
        const SizedBox(height: 8),
        _MrzModuleCard(config: config, onChanged: onChanged),
        const SizedBox(height: 8),
        _VizModuleCard(config: config, onChanged: onChanged),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              config.resetToDefaults();
              onChanged();
            },
            child: const Text('Reset to defaults'),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final List<Widget> children;

  const _ModuleCard({
    required this.title,
    this.subtitle,
    required this.enabled,
    required this.onEnabledChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: enabled
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: enabled,
          enabled: enabled,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onEnabledChanged,
              ),
            ],
          ),
          children: enabled
              ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Column(children: children),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }
}

class _BarcodeModuleCard extends StatelessWidget {
  final ScanningModulesConfig config;
  final VoidCallback onChanged;

  const _BarcodeModuleCard({required this.config, required this.onChanged});

  void _updateBarcode(void Function(BarcodeModuleSettings s) update) {
    update(config.barcode);
    onChanged();
  }

  void _setPdf417(bool value) {
    _updateBarcode((s) {
      s.pdf417ScanningEnabled = value;
      if (value) s.qrScanningEnabled = true;
    });
  }

  void _setQr(bool value) {
    _updateBarcode((s) {
      s.qrScanningEnabled = value;
      if (value) s.pdf417ScanningEnabled = true;
      if (!value && s.pdf417ScanningEnabled) {
        s.pdf417ScanningEnabled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = config.barcode;
    return _ModuleCard(
      title: 'Barcode',
      subtitle: config.barcodeEnabled ? 'Enabled' : 'Disabled (null)',
      enabled: config.barcodeEnabled,
      onEnabledChanged: (v) {
        config.barcodeEnabled = v;
        onChanged();
      },
      children: [
        _SectionLabel('Presence & image'),
        _BoolSettingTile(
          title: 'Presence mandatory',
          subtitle: 'Barcode must be present on scanned side(s)',
          value: b.presenceMandatory,
          onChanged: (v) => _updateBarcode((s) => s.presenceMandatory = v),
        ),
        _BoolSettingTile(
          title: 'Barcode image return',
          value: b.barcodeImageReturnEnabled,
          onChanged: (v) =>
              _updateBarcode((s) => s.barcodeImageReturnEnabled = v),
        ),
        _SectionLabel('Document barcodes'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'PDF417 and QR should be enabled together to avoid scan hangs.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _BoolSettingTile(
          title: 'PDF417 scanning',
          value: b.pdf417ScanningEnabled,
          onChanged: _setPdf417,
        ),
        _BoolSettingTile(
          title: 'QR scanning',
          value: b.qrScanningEnabled,
          onChanged: _setQr,
        ),
        _SectionLabel('Retail formats'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Retail formats apply when document capture is disabled.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _BoolSettingTile(
          title: 'UPC-E',
          value: b.upceScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.upceScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'UPC-A',
          value: b.upcaScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.upcaScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'Code 128',
          value: b.code128ScanningEnabled,
          onChanged: (v) =>
              _updateBarcode((s) => s.code128ScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'Code 39',
          value: b.code39ScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.code39ScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'EAN-8',
          value: b.ean8ScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.ean8ScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'EAN-13',
          value: b.ean13ScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.ean13ScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'ITF',
          value: b.itfScanningEnabled,
          onChanged: (v) => _updateBarcode((s) => s.itfScanningEnabled = v),
        ),
        _BoolSettingTile(
          title: 'DataMatrix',
          value: b.dataMatrixScanningEnabled,
          onChanged: (v) =>
              _updateBarcode((s) => s.dataMatrixScanningEnabled = v),
        ),
      ],
    );
  }
}

class _DocumentCaptureModuleCard extends StatelessWidget {
  final ScanningModulesConfig config;
  final VoidCallback onChanged;

  const _DocumentCaptureModuleCard({
    required this.config,
    required this.onChanged,
  });

  void _update(void Function(DocumentCaptureModuleSettings s) update) {
    update(config.documentCapture);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = config.documentCapture;
    return _ModuleCard(
      title: 'Document capture',
      subtitle: config.documentCaptureEnabled ? 'Enabled' : 'Disabled (null)',
      enabled: config.documentCaptureEnabled,
      onEnabledChanged: (v) {
        config.documentCaptureEnabled = v;
        onChanged();
      },
      children: [
        _SectionLabel('Images & return'),
        _BoolSettingTile(
          title: 'Document image return',
          value: d.documentImageReturnEnabled,
          onChanged: (v) =>
              _update((s) => s.documentImageReturnEnabled = v),
        ),
        _BoolSettingTile(
          title: 'Input image return',
          subtitle: 'Increases memory usage',
          value: d.inputImageReturnEnabled,
          onChanged: (v) => _update((s) => s.inputImageReturnEnabled = v),
        ),
        _BoolSettingTile(
          title: 'Unsupported documents allowed',
          value: d.unsupportedDocumentsAllowed,
          onChanged: (v) =>
              _update((s) => s.unsupportedDocumentsAllowed = v),
        ),
        _BoolSettingTile(
          title: 'Skip second side with no extractable data',
          value: d.secondSideWithNoExtractableDataSkipped,
          onChanged: (v) =>
              _update((s) => s.secondSideWithNoExtractableDataSkipped = v),
        ),
        _SectionLabel('Face & passport'),
        _BoolSettingTile(
          title: 'Face image extraction',
          value: d.faceImageExtractionEnabled,
          onChanged: (v) =>
              _update((s) => s.faceImageExtractionEnabled = v),
        ),
        _BoolSettingTile(
          title: 'Face image presence mandatory',
          value: d.faceImagePresenceMandatory,
          onChanged: (v) =>
              _update((s) => s.faceImagePresenceMandatory = v),
        ),
        _BoolSettingTile(
          title: 'Passport data page scan only',
          value: d.passportDataPageScanOnly,
          onChanged: (v) => _update((s) => s.passportDataPageScanOnly = v),
        ),
        _SectionLabel('Image quality'),
        _SensitivityDropdown(
          label: 'Blur sensitivity',
          value: d.blurSensitivityLevel,
          onChanged: (v) => _update((s) => s.blurSensitivityLevel = v),
        ),
        _BoolSettingTile(
          title: 'Reject image with blur',
          value: d.imageWithBlurRejected,
          onChanged: (v) => _update((s) => s.imageWithBlurRejected = v),
        ),
        _SensitivityDropdown(
          label: 'Glare sensitivity',
          value: d.glareSensitivityLevel,
          onChanged: (v) => _update((s) => s.glareSensitivityLevel = v),
        ),
        _BoolSettingTile(
          title: 'Reject image with glare',
          value: d.imageWithGlareRejected,
          onChanged: (v) => _update((s) => s.imageWithGlareRejected = v),
        ),
        _SensitivityDropdown(
          label: 'Tilt sensitivity',
          value: d.tiltSensitivityLevel,
          onChanged: (v) => _update((s) => s.tiltSensitivityLevel = v),
        ),
        _BoolSettingTile(
          title: 'Reject poor lighting',
          value: d.imageWithPoorLightingRejected,
          onChanged: (v) =>
              _update((s) => s.imageWithPoorLightingRejected = v),
        ),
        _BoolSettingTile(
          title: 'Reject hand occlusion',
          value: d.imageWithHandOcclusionRejected,
          onChanged: (v) =>
              _update((s) => s.imageWithHandOcclusionRejected = v),
        ),
        _IntSettingField(
          label: 'Dots per inch',
          value: d.dotsPerInch,
          min: 100,
          max: 400,
          onChanged: (v) => _update((s) => s.dotsPerInch = v),
        ),
        _DoubleSettingField(
          label: 'Extension factor',
          value: d.extensionFactor,
          min: 0,
          max: 1,
          onChanged: (v) => _update((s) => s.extensionFactor = v),
        ),
        _SectionLabel('Direct API'),
        _BoolSettingTile(
          title: 'Input image cropped',
          subtitle: 'For pre-cropped Direct API images only',
          value: d.inputImageCropped,
          onChanged: (v) => _update((s) => s.inputImageCropped = v),
        ),
        _DoubleSettingField(
          label: 'Input image margin',
          value: d.inputImageMargin ?? 0.02,
          min: 0,
          max: 1,
          onChanged: (v) => _update((s) => s.inputImageMargin = v),
        ),
      ],
    );
  }
}

class _MrzModuleCard extends StatelessWidget {
  final ScanningModulesConfig config;
  final VoidCallback onChanged;

  const _MrzModuleCard({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _ModuleCard(
      title: 'MRZ',
      subtitle: config.mrzEnabled ? 'Enabled' : 'Disabled (null)',
      enabled: config.mrzEnabled,
      onEnabledChanged: (v) {
        config.mrzEnabled = v;
        onChanged();
      },
      children: [
        _BoolSettingTile(
          title: 'Presence mandatory',
          subtitle: 'MRZ must be present on scanned side(s)',
          value: config.mrz.presenceMandatory,
          onChanged: (v) {
            config.mrz.presenceMandatory = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _VizModuleCard extends StatelessWidget {
  final ScanningModulesConfig config;
  final VoidCallback onChanged;

  const _VizModuleCard({required this.config, required this.onChanged});

  void _update(void Function(VizModuleSettings s) update) {
    update(config.viz);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final v = config.viz;
    return _ModuleCard(
      title: 'VIZ',
      subtitle: config.vizEnabled ? 'Enabled' : 'Disabled (null)',
      enabled: config.vizEnabled,
      onEnabledChanged: (v) {
        config.vizEnabled = v;
        onChanged();
      },
      children: [
        _BoolSettingTile(
          title: 'Presence mandatory',
          value: v.presenceMandatory,
          onChanged: (val) => _update((s) => s.presenceMandatory = val),
        ),
        _BoolSettingTile(
          title: 'Signature image extraction',
          value: v.signatureImageExtractionEnabled,
          onChanged: (val) =>
              _update((s) => s.signatureImageExtractionEnabled = val),
        ),
        _BoolSettingTile(
          title: 'Character validation',
          value: v.characterValidationEnabled,
          onChanged: (val) =>
              _update((s) => s.characterValidationEnabled = val),
        ),
        _BoolSettingTile(
          title: 'Result aggregation',
          subtitle: 'Aggregate data from multiple frames (video only)',
          value: v.resultAggregationEnabled,
          onChanged: (val) => _update((s) => s.resultAggregationEnabled = val),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BoolSettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BoolSettingTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _SensitivityDropdown extends StatelessWidget {
  final String label;
  final SensitivityLevel value;
  final ValueChanged<SensitivityLevel> onChanged;

  const _SensitivityDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<SensitivityLevel>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: SensitivityLevel.values
            .map(
              (level) => DropdownMenuItem(
                value: level,
                child: Text(level.name),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _IntSettingField extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntSettingField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_IntSettingField> createState() => _IntSettingFieldState();
}

class _IntSettingFieldState extends State<_IntSettingField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_IntSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
      widget.onChanged(parsed);
    } else {
      _controller.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: '${widget.min}–${widget.max}',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onFieldSubmitted: (_) => _commit(),
        onEditingComplete: _commit,
      ),
    );
  }
}

class _DoubleSettingField extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _DoubleSettingField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_DoubleSettingField> createState() => _DoubleSettingFieldState();
}

class _DoubleSettingFieldState extends State<_DoubleSettingField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_DoubleSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text);
    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
      widget.onChanged(parsed);
    } else {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: '${widget.min}–${widget.max}',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onFieldSubmitted: (_) => _commit(),
        onEditingComplete: _commit,
      ),
    );
  }
}
