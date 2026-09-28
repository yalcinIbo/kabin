import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/social_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref.read(authNotifierProvider.notifier).signInWithEmail(_email.text, _password.text);
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
    final notifier = ref.read(authNotifierProvider.notifier);

    return AuthScaffold(
      title: 'Kabine hoş geldin',
      subtitle: 'Aldığın kıyafetin üstünde nasıl duracağını satın almadan gör.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _email,
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline_rounded,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _password,
                label: 'Şifre',
                obscure: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v ?? '').isEmpty ? 'Şifre gerekli.' : null,
                onSubmitted: (_) => _submit(),
                enabled: !isLoading,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : () => context.push(RouteNames.forgotPassword),
                  child: const Text('Şifremi unuttum'),
                ),
              ),
              AppButton(label: 'Giriş yap', isLoading: isLoading, onPressed: _submit),
            ],
          ),
        ),
        const OrDivider(),
        SocialButtons(enabled: !isLoading, onGoogle: notifier.signInWithGoogle, onApple: notifier.signInWithApple),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Hesabın yok mu?'),
            TextButton(onPressed: isLoading ? null : () => context.push(RouteNames.register), child: const Text('Kayıt ol')),
          ],
        ),
      ],
    );
  }
}
