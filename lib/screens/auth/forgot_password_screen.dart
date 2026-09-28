import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authNotifierProvider.notifier).sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
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
    return AuthScaffold(
      title: 'Şifreni sıfırla',
      subtitle: 'E-posta adresine sıfırlama bağlantısı göndereceğiz.',
      appBar: true,
      showLogo: false,
      children: [
        if (_sent)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.mark_email_read_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Bağlantı gönderildi: ${_email.text.trim()}. Gelen kutunu kontrol et.')),
                ],
              ),
            ),
          )
        else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _email,
                  label: 'E-posta',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                AppButton(label: 'Bağlantı gönder', isLoading: isLoading, onPressed: _submit),
              ],
            ),
          ),
      ],
    );
  }
}
