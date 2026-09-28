import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Alt sekme kabuğu: Dene, Dolabım, Geçmiş, Profil. Yüzen, koyu kadife hap menü.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Sekme ekranlarının içerik altına bırakması gereken boşluk (yüzen menü + güvenli alan).
  static double bottomInset(BuildContext context) => 96 + MediaQuery.paddingOf(context).bottom;

  static const _items = [
    _NavItem(Icons.checkroom_outlined, Icons.checkroom_rounded, 'Dene'),
    _NavItem(Icons.door_sliding_outlined, Icons.door_sliding_rounded, 'Dolabım'),
    _NavItem(Icons.history_rounded, Icons.history_rounded, 'Geçmiş'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 66,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.plum950.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      _NavButton(
                        item: _items[i],
                        selected: i == navigationShell.currentIndex,
                        onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.labelMedium;
    return Expanded(
      flex: selected ? 5 : 3,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(color: selected ? AppColors.ivory : AppColors.transparent, borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 21,
                  color: selected ? AppColors.plum900 : AppColors.moon.withValues(alpha: 0.62),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Text(item.label, maxLines: 1, style: text?.copyWith(color: AppColors.plum900, fontSize: 13)),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
