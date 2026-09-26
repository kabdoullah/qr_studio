import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_layout.dart';
import '../widgets/social_sign_in_buttons.dart';

// Connexion. Une fois connecté, le routeur ouvre l'accueil.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authViewModelProvider.notifier)
        .login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    return AuthLayout(
      title: 'Connexion',
      subtitle: 'Créez et partagez vos QR Codes.',
      errorMessage: auth.errorMessage,
      children: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (v) => AuthViewModel.validateEmail(v ?? ''),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Mot de passe',
                autofillHints: const [AutofillHints.password],
                // À la connexion, seul un champ vide est signalé : la
                // longueur est vérifiée par le serveur.
                validator: (v) =>
                    v.isEmpty ? 'Veuillez saisir votre mot de passe.' : null,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              SubmitButton(
                label: 'Se connecter',
                busyLabel: 'Connexion…',
                isBusy: auth.isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SocialSignInButtons(),
        const SizedBox(height: 32),
        Text(
          'Pas encore de compte ?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: auth.isSubmitting
              ? null
              : () {
                  ref.read(authViewModelProvider.notifier).clearError();
                  context.push(AppRoutes.register);
                },
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}
