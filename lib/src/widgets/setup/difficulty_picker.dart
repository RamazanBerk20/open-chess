import 'package:flutter/material.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/theme/spacing.dart';

/// Difficulty selector: preset chips + a Custom option exposing bounded
/// inaccuracy controls. Emits the effective [Difficulty] via [onChanged].
/// Used by the on-device computer setup.
class DifficultyPicker extends StatefulWidget {
  final Difficulty initial;
  final ValueChanged<Difficulty> onChanged;
  const DifficultyPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<DifficultyPicker> createState() => _DifficultyPickerState();
}

class _DifficultyPickerState extends State<DifficultyPicker> {
  late Difficulty _preset;
  bool _custom = false;
  int _depth = 5, _timeMs = 800, _maxLoss = 90;
  double _variety = 0.20;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial;
  }

  Difficulty get _effective => _custom
      ? Difficulty(
          'Custom',
          maxDepth: _depth,
          moveTimeMs: _timeMs,
          maxEvalLossCp: _maxLoss,
          randomMoveChance: _variety,
          candidateDepth: _depth.clamp(1, 5),
        )
      : _preset;

  void _emit() => widget.onChanged(_effective);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in Difficulty.presets)
              ChoiceChip(
                label: Text(localizedDifficulty(t, d.name)),
                selected: !_custom && _preset.name == d.name,
                onSelected: (_) {
                  setState(() {
                    _custom = false;
                    _preset = d;
                  });
                  _emit();
                },
              ),
            ChoiceChip(
              label: Text(t.custom),
              selected: _custom,
              onSelected: (_) {
                setState(() => _custom = true);
                _emit();
              },
            ),
          ],
        ),
        if (_custom) ...[
          AppSpacing.gap,
          _slider(t.searchDepth, _depth.toDouble(), 1, 18, '$_depth', (v) {
            setState(() => _depth = v.round());
            _emit();
          }),
          _slider(t.timePerMove, _timeMs.toDouble(), 100, 10000, '$_timeMs', (
            v,
          ) {
            setState(() => _timeMs = v.round());
            _emit();
          }),
          _slider(t.maxEvalLoss, _maxLoss.toDouble(), 0, 500, '$_maxLoss', (v) {
            setState(() => _maxLoss = v.round());
            _emit();
          }),
          _slider(t.moveVariety, _variety, 0, 1, _variety.toStringAsFixed(2), (
            v,
          ) {
            setState(() => _variety = v);
            _emit();
          }),
        ],
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text('$label: $display')),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
