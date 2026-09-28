import 'package:flutter/material.dart';
// Paketin Flutter3DViewer sarmalayıcısı ışık/pozlama ayarlarını dışarı açmıyor; alttaki model-viewer bileşenini doğrudan kullanıyoruz.
// ignore: implementation_imports
import 'package:flutter_3d_controller/src/core/modules/model_viewer/model_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../models/model3d/model3d_model.dart';
import '../../providers/credit/credit_providers.dart';
import '../../providers/model3d/model3d_providers.dart';

/// model-viewer görünüm ayarları.
abstract final class ModelViewerLook {
  /// `tone-mapping` özniteliğini bileşen yüklenmeden önce yazar (Lit yükseltmede okur).
  static const toneMappingJs =
      "document.querySelectorAll('model-viewer').forEach(function (m) { m.setAttribute('tone-mapping', 'commerce'); });";
}

/// 3D model işinin ilerlemesi ve hazır olduğunda döndürülebilir görüntüleyici.
class Model3DViewerScreen extends ConsumerWidget {
  const Model3DViewerScreen({super.key, required this.modelId});

  final String modelId;

  /// Başarısız işi aynı denemeden yeniden ister; yeni iş ekranı bu ekranın yerine açılır.
  Future<void> _retry(BuildContext context, WidgetRef ref, Model3DModel model) async {
    final cost = ref.read(pricingProvider).value?.model3d ?? 5;
    final ok = await AppFeedback.confirm(
      context,
      title: 'Tekrar dene',
      message: '3D model yeniden oluşturulacak ($cost kredi). Başarısız olursa kredin yine iade edilir.',
      confirmLabel: 'Oluştur',
    );
    if (!ok || !context.mounted) return;
    final notifier = ref.read(model3dRequestNotifierProvider(model.tryonId).notifier);
    final newId = await notifier.request();
    if (!context.mounted) return;
    if (newId != null) {
      context.pushReplacement(RouteNames.model3d(newId));
    } else {
      final error = ref.read(model3dRequestNotifierProvider(model.tryonId)).error;
      if (error != null) AppFeedback.showError(context, error);
      notifier.clearError();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(model3dProvider(modelId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('3D model')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: '3D model yüklenemedi.'),
        data: (model) {
          if (model == null) return const EmptyView(title: 'Model bulunamadı', icon: Icons.view_in_ar_outlined);
          if (model.status.isActive) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: JobProgressView(
                  status: model.status,
                  stage: model.stage,
                  progress: model.progress,
                  hint: '3D model oluşturmak 1-3 dakika sürebilir. Ekrandan çıkabilirsin; model denemenin içinde kalır.',
                ),
              ),
            );
          }
          if (model.status == JobStatus.failed) {
            return ErrorView(
              message: '${model.error?.messageTr ?? '3D model oluşturulamadı.'}${model.refunded ? '\nKredin iade edildi.' : ''}',
              onRetry: model.tryonId.isEmpty ? null : () => _retry(context, ref, model),
            );
          }
          return ref
              .watch(localGlbProvider(modelId))
              .when(
                loading: () => const LoadingView(message: 'Model indiriliyor…'),
                error: (e, _) => ErrorView(message: 'Model dosyası açılamadı.', onRetry: () => ref.invalidate(localGlbProvider(modelId))),
                data: (file) => Column(
                  children: [
                    Expanded(
                      child: ModelViewer(
                        src: Uri.file(file.path).toString(),
                        progressBarColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                        activeGestureInterceptor: true,
                        cameraControls: true,
                        disablePan: true,
                        disableTap: true,
                        interactionPrompt: InteractionPrompt.none,
                        ar: false,
                        autoRotate: true,
                        autoRotateDelay: 3500,
                        rotationPerSecond: '18deg',
                        cameraOrbit: '0deg 82deg auto',
                        // Nötr stüdyo ışığı + biraz yüksek pozlama; varsayılan ışık dokuları koyu ve kahverengimsi gösteriyordu.
                        environmentImage: 'neutral',
                        exposure: 1.2,
                        shadowIntensity: 0.7,
                        shadowSoftness: 1,
                        // "commerce" ton eşleme, kiremit gibi doygun renkleri soldurmadan olduğu gibi gösterir.
                        relatedJs: ModelViewerLook.toneMappingJs,
                        debugLogging: false,
                        onError: (_) {},
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Döndürmek için sürükle, yakınlaştırmak için iki parmak kullan. Model yapay zekâ ile tahmin edilmiştir.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
        },
      ),
    );
  }
}
