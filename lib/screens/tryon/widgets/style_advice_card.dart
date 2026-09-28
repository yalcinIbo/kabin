import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/tryon/tryon_job_model.dart';

/// Gemini stil asistanının Türkçe yorumu: koyu kadife "stil notu" kartı, dergi alıntısı gibi.
class StyleAdviceCard extends StatelessWidget {
  const StyleAdviceCard({super.key, required this.advice});

  final StyleAdviceModel advice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fg = AppColors.moon;
    final muted = AppColors.moon.withValues(alpha: 0.62);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.plum800, AppColors.plum950],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 18, height: 1.4, color: AppColors.brass),
              const SizedBox(width: 8),
              Text('STİL NOTU', style: AppType.overline(AppColors.brassLight)),
              const Spacer(),
              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.brassLight),
            ],
          ),
          if (advice.fitTr.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '“${advice.fitTr}”',
              style: AppType.serif(size: 21, italic: true, weight: FontWeight.w400, color: fg, height: 1.3, letterSpacing: -0.2),
            ),
          ],
          if (advice.sizeAdviceTr.isNotEmpty || advice.occasionTr.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: AppColors.moon.withValues(alpha: 0.12)),
            if (advice.sizeAdviceTr.isNotEmpty) _Fact(label: 'Beden', text: advice.sizeAdviceTr, muted: muted),
            if (advice.occasionTr.isNotEmpty) _Fact(label: 'Nerede', text: advice.occasionTr, muted: muted),
          ],
          if (advice.tipsTr.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('KOMBİN ÖNERİLERİ', style: AppType.overline(muted, size: 10)),
            const SizedBox(height: 6),
            for (var i = 0; i < advice.tipsTr.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: AppType.serif(size: 18, italic: true, color: AppColors.terracotta, height: 1.3),
                      ),
                    ),
                    Expanded(
                      child: Text(advice.tipsTr[i], style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.text, required this.muted});

  final String label;
  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label.toUpperCase(), style: AppType.overline(muted, size: 10))),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.moon)),
        ),
      ],
    ),
  );
}
