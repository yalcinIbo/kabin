import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/user/user_providers.dart';
import '../home/app_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = user?.measurements;
    final name = (user?.displayName.isNotEmpty ?? false) ? user!.displayName : 'Kabin kullanıcısı';
    final hasMeasurements = m != null && (m.heightCm != null || m.weightKg != null);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, AppShell.bottomInset(context)),
          children: [
            Row(
              children: [
                const Expanded(child: Overline('Profil')),
                IconButton(
                  tooltip: 'Ayarlar',
                  style: IconButton.styleFrom(
                    side: BorderSide(color: scheme.outlineVariant),
                    backgroundColor: scheme.surfaceContainerLowest,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  onPressed: () => context.push(RouteNames.settings),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.plum700, AppColors.plum950],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Text(name.characters.first.toUpperCase(), style: AppType.serif(size: 28, italic: true, color: AppColors.moon)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppType.serif(size: 26, color: scheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user?.email != null)
                        Text(user!.email!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _CreditCard(credits: user?.credits ?? 0, onTap: () => context.push(RouteNames.credits)),
            const SizedBox(height: 16),
            PaperCard(
              onTap: () => context.push(RouteNames.measurements),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ÖLÇÜLERİM', style: AppType.overline(scheme.onSurfaceVariant, size: 10)),
                        const SizedBox(height: 10),
                        if (hasMeasurements)
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              if (m.heightCm != null) _Metric(value: '${m.heightCm}', unit: 'cm'),
                              if (m.weightKg != null) _Metric(value: '${m.weightKg}', unit: 'kg'),
                              if (m.bodyType != null) _Metric(value: m.bodyType!.labelTr, unit: ''),
                            ],
                          )
                        else
                          Text('Beden tavsiyesi için ölçülerini ekle', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PaperCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _Row(icon: Icons.door_sliding_outlined, title: 'Dolabım', onTap: () => context.go(RouteNames.wardrobe)),
                  const Divider(height: 1, indent: 18, endIndent: 18),
                  _Row(icon: Icons.shield_outlined, title: 'Gizlilik ve KVKK', onTap: () => context.push(RouteNames.legal)),
                  const Divider(height: 1, indent: 18, endIndent: 18),
                  _Row(icon: Icons.tune_rounded, title: 'Ayarlar', onTap: () => context.push(RouteNames.settings)),
                  if (isAdmin) ...[
                    const Divider(height: 1, indent: 18, endIndent: 18),
                    _Row(
                      icon: Icons.compare_rounded,
                      title: 'Sağlayıcı karşılaştırması',
                      subtitle: 'FASHN × Vertex (yönetici)',
                      onTap: () => context.push(RouteNames.benchmark),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Center(child: Wordmark(size: 22)),
            const SizedBox(height: 4),
            Center(
              child: Text('Üstünde nasıl durur?', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credits, required this.onTap});

  final int credits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [AppColors.plum800, AppColors.plum950],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Köşede silik perde kıvrımları.
                Positioned(
                  right: -10,
                  top: 0,
                  bottom: 0,
                  width: 120,
                  child: Opacity(opacity: 0.55, child: CustomPaint(painter: CurtainPainter(open: 0.7))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KREDİ BAKİYEN', style: AppType.overline(AppColors.brassLight, size: 10)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$credits',
                            style: AppType.serif(size: 52, color: AppColors.moon, weight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text('kredi', style: AppType.serif(size: 18, italic: true, color: AppColors.moon.withValues(alpha: 0.7))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Hareketler ve fiyatlar', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.moon)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.moon),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: AppType.serif(size: 24, color: scheme.onSurface),
          ),
          if (unit.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: AppType.serif(size: 15, italic: true, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
