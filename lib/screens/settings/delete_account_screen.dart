import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/enums.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';

/// KVKK: hesabı ve tüm verileri kalıcı silme.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirmText = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        AppFeedback.showError(context, error);
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });
    final isLoading = ref.watch(authNotifierProvider.select((s) => s.isLoading));
    final isEmail = ref.read(authRepositoryProvider).currentProvider == AuthProviderType.email;
    final theme = Theme.of(context);
    final canDelete = isDeleteConfirmation(_confirmText.text) && (!isEmail || _password.text.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabı sil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Bu işlem geri alınamaz', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Hesabın silindiğinde:\n'
            '• Tüm fotoğrafların, kıyafetlerin, denemelerin ve 3D modellerin kalıcı olarak silinir.\n'
            '• Kalan kredilerin geri alınamaz.\n'
            '• Güvenlik için giriş yöntemini yeniden doğrulaman istenir.',
          ),
          const SizedBox(height: 24),
          if (isEmail) ...[
            AppTextField(controller: _password, label: 'Şifreni doğrula', obscure: true, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
          ],
          AppTextField(
            controller: _confirmText,
            label: 'Onaylamak için "SİL" yaz',
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Hesabımı kalıcı olarak sil',
            variant: AppButtonVariant.danger,
            isLoading: isLoading,
            onPressed: canDelete
                ? () async {
                    final ok = await AppFeedback.confirm(
                      context,
                      title: 'Son onay',
                      message: 'Hesabın ve tüm verilerin kalıcı olarak silinecek.',
                      confirmLabel: 'Kalıcı olarak sil',
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref.read(authNotifierProvider.notifier).deleteAccount(password: isEmail ? _password.text : null);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// "SİL" onayı. Dart'ın `toUpperCase`'i Türkçe'ye duyarlı değil ("sil" → "SIL"); bu yüzden İ/I/ı farkı yok sayılır.
bool isDeleteConfirmation(String input) {
  final normalized = input.trim().toUpperCase().replaceAll('İ', 'I').replaceAll('ı'.toUpperCase(), 'I');
  return normalized == 'SIL';
}
