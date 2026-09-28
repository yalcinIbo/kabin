import 'package:flutter/material.dart';

import '../../../core/enums/enums.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/garment/garment_model.dart';

/// Gemini analizinin kullanıcı tarafından düzeltilmesi.
class AnalysisEditForm extends StatefulWidget {
  const AnalysisEditForm({super.key, required this.analysis, required this.onChanged, this.enabled = true});

  final GarmentAnalysisModel analysis;
  final ValueChanged<GarmentAnalysisModel> onChanged;
  final bool enabled;

  @override
  State<AnalysisEditForm> createState() => _AnalysisEditFormState();
}

class _AnalysisEditFormState extends State<AnalysisEditForm> {
  late final _title = TextEditingController(text: widget.analysis.titleTr);
  late final _color = TextEditingController(text: widget.analysis.colorNameTr);

  @override
  void dispose() {
    _title.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _title,
          label: 'Başlık',
          maxLength: 60,
          enabled: widget.enabled,
          validator: Validators.garmentTitle,
          onChanged: (v) => widget.onChanged(a.copyWith(titleTr: v.trim())),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: a.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _color,
                label: 'Renk',
                maxLength: 40,
                enabled: widget.enabled,
                onChanged: (v) => widget.onChanged(a.copyWith(colorNameTr: v.trim())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Kategori', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in GarmentCategory.values)
              ChoiceChip(
                label: Text(c.labelTr),
                selected: a.category == c,
                onSelected: widget.enabled ? (_) => widget.onChanged(a.copyWith(category: c)) : null,
              ),
          ],
        ),
        if (!a.category.isTryOnSupported) ...[
          const SizedBox(height: 8),
          Text(
            'Ayakkabı ve aksesuarlar henüz denenemiyor; dolabında saklanır.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Text('Fotoğraf türü', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in GarmentPhotoType.values)
              ChoiceChip(
                label: Text(t.labelTr),
                selected: a.garmentPhotoType == t,
                onSelected: widget.enabled ? (_) => widget.onChanged(a.copyWith(garmentPhotoType: t)) : null,
              ),
          ],
        ),
        if (a.fabricGuess.isNotEmpty || a.descriptionTr.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            [if (a.fabricGuess.isNotEmpty) 'Kumaş tahmini: ${a.fabricGuess}', if (a.descriptionTr.isNotEmpty) a.descriptionTr].join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
