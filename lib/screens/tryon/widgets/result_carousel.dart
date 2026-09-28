import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/tryon/tryon_job_model.dart';

/// Döner sahne: sonucu yatay sürükleyerek ön → yan → arka arasında "döndürürsün".
/// Tüm açılar üst üste yüklü tutulur; geçiş anında olur, yeniden yükleme yanıp sönmesi olmaz. Dokununca tam ekran yakınlaştırma.
class ResultCarousel extends StatefulWidget {
  const ResultCarousel({super.key, required this.results, this.onPageChanged});

  final List<TryOnResultModel> results;
  final ValueChanged<TryOnResultModel>? onPageChanged;

  @override
  State<ResultCarousel> createState() => _ResultCarouselState();
}

class _ResultCarouselState extends State<ResultCarousel> {
  int _index = 0;
  double _drag = 0;
  bool _hintVisible = true;

  static const _stepPx = 70.0;

  List<TryOnResultModel> get _items {
    final list = [...widget.results];
    list.sort((a, b) => a.angle.index.compareTo(b.angle.index));
    return list;
  }

  void _go(int i) {
    final items = _items;
    if (items.isEmpty) return;
    final next = i.clamp(0, items.length - 1);
    if (next == _index) return;
    setState(() {
      _index = next;
      _hintVisible = false;
    });
    widget.onPageChanged?.call(items[next]);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _drag += d.delta.dx;
    // Sola sürüklemek modeli saat yönünde çevirir: ön → yan → arka.
    if (_drag <= -_stepPx) {
      _drag = 0;
      _go(_index + 1);
    } else if (_drag >= _stepPx) {
      _drag = 0;
      _go(_index - 1);
    }
  }

  void _openFull(TryOnResultModel r) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.black.withValues(alpha: 0.92),
        pageBuilder: (context, _, _) => _FullScreenImage(path: r.storagePath),
        transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();
    final current = items[_index.clamp(0, items.length - 1)];
    final providers = items.map((r) => r.provider).toSet();

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: items.length > 1 ? _onDragUpdate : null,
          onHorizontalDragEnd: (_) => _drag = 0,
          onTap: () => _openFull(current),
          child: AspectRatio(
            aspectRatio: items.first.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < items.length; i++)
                    AnimatedOpacity(
                      opacity: i == _index ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: i == _index ? 1 : 1.03,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        child: StorageImage(path: items[i].storagePath, cacheWidth: AppConstants.detailCacheWidth),
                      ),
                    ),
                  // Alt gölge: açı göstergesi okunaklı olsun.
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(0, 0.35),
                          end: Alignment.bottomCenter,
                          colors: [AppColors.transparent, AppColors.plumShade],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: StatusBadge(
                      label: providers.length > 1 ? '${current.angle.labelTr} · ${current.provider.toUpperCase()}' : current.angle.labelTr,
                      tone: BadgeTone.positive,
                      onImage: true,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: AppColors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                      child: const Icon(Icons.open_in_full_rounded, size: 16, color: AppColors.white),
                    ),
                  ),
                  if (items.length > 1)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _AngleDial(
                        labels: [for (final r in items) r.angle.labelTr],
                        index: _index,
                        onSelect: _go,
                        showHint: _hintVisible,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  onTap: () => _go(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 46,
                    height: 60,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == _index ? scheme.secondary : AppColors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Opacity(
                        opacity: i == _index ? 1 : 0.55,
                        child: StorageImage(path: items[i].storagePath, cacheWidth: 200),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Görsel üzerindeki açı kadranı: ÖN · YAN · ARKA, seçili olanın altında kayan çizgi.
class _AngleDial extends StatelessWidget {
  const _AngleDial({required this.labels, required this.index, required this.onSelect, required this.showHint});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: showHint ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swipe_rounded, size: 16, color: AppColors.white),
                const SizedBox(width: 6),
                Text('Sürükle, döndür', style: AppType.overline(AppColors.white, size: 10)),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final segW = c.maxWidth / labels.length;
            return SizedBox(
              height: 34,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: segW * index + segW * 0.3,
                    width: segW * 0.4,
                    bottom: 0,
                    height: 2,
                    child: Container(color: AppColors.terracotta),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(i),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: AppType.overline(AppColors.white.withValues(alpha: i == index ? 1 : 0.55), size: 11),
                                child: Text(labels[i].toUpperCase()),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: StorageImage(path: path, fit: BoxFit.contain, cacheWidth: AppConstants.detailCacheWidth),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.white.withValues(alpha: 0.15)),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
