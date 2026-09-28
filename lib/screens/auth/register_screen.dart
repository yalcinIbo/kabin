import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/social_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref.read(authNotifierProvider.notifier).signUpWithEmail(_email.text, _password.text);
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
      title: 'Hesap oluştur',
      subtitle: 'Kayıt olana hoş geldin kredisi hediye.',
      appBar: true,
      showLogo: false,
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
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.lock_outline_rounded,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                helperText: 'En az 8 karakter, harf ve rakam içermeli.',
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _confirm,
                label: 'Şifre (tekrar)',
                obscure: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              AppButton(label: 'Kayıt ol', isLoading: isLoading, onPressed: _submit),
            ],
          ),
        ),
        const OrDivider(),
        SocialButtons(enabled: !isLoading, onGoogle: notifier.signInWithGoogle, onApple: notifier.signInWithApple),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Zaten hesabın var mı?'),
            TextButton(onPressed: isLoading ? null : () => context.go(RouteNames.login), child: const Text('Giriş yap')),
          ],
        ),
      ],
    );
  }
}
