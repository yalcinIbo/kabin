import 'package:flutter/material.dart';

import '../../models/user/user_model.dart';
import '../constants/app_constants.dart';
import '../enums/enums.dart';

/// Boy / kilo / vücut tipi / cinsiyet seçimi (onboarding, profil ve selfie avatar ortak).
class MeasurementsForm extends StatelessWidget {
  const MeasurementsForm({super.key, required this.value, required this.onChanged, this.enabled = true, this.showGender = true});

  final Measurements value;
  final ValueChanged<Measurements> onChanged;
  final bool enabled;
  final bool showGender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = value.heightCm ?? 170;
    final weight = value.weightKg ?? 65;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SliderRow(
          label: 'Boy',
          unit: 'cm',
          value: height,
          isSet: value.heightCm != null,
          min: AppConstants.minHeightCm,
          max: AppConstants.maxHeightCm,
          enabled: enabled,
          onChanged: (v) => onChanged(value.copyWith(heightCm: v, weightKg: value.weightKg ?? weight)),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Kilo',
          unit: 'kg',
          value: weight,
          isSet: value.weightKg != null,
          min: AppConstants.minWeightKg,
          max: 160,
          enabled: enabled,
          onChanged: (v) => onChanged(value.copyWith(weightKg: v, heightCm: value.heightCm ?? height)),
        ),
        const SizedBox(height: 16),
        Text('Vücut tipi', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in BodyType.values)
              ChoiceChip(
                label: Text(t.labelTr),
                selected: value.bodyType == t,
                onSelected: enabled ? (_) => onChanged(value.copyWith(bodyType: t)) : null,
              ),
          ],
        ),
        if (showGender) ...[
          const SizedBox(height: 16),
          Text('Cinsiyet (avatar üretimi için)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in Gender.values)
                ChoiceChip(
                  label: Text(g.labelTr),
                  selected: value.gender == g,
                  onSelected: enabled ? (_) => onChanged(value.copyWith(gender: g)) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.isSet,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final int value;
  final bool isSet;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              isSet ? '$clamped $unit' : 'Seçilmedi',
              style: theme.textTheme.titleSmall?.copyWith(color: isSet ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        Slider(
          value: clamped.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$clamped $unit',
          onChanged: enabled ? (v) => onChanged(v.round()) : null,
        ),
      ],
    );
  }
}
