import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

import '../../../core/utils/validators.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/loading_button.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_layout.dart';
import '../widgets/social_sign_in_buttons.dart';

// Création de compte. Le compte créé est aussitôt connecté.
class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authViewModelProvider.notifier)
        .register(
          firstName: _firstName.text,
          lastName: _lastName.text,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    return AuthLayout(
      title: 'Créer un compte',
      subtitle: 'Retrouvez vos QR Codes sur tous vos appareils.',
      errorMessage: auth.errorMessage,
      showBackButton: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'Prénom'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: (v) => Validators.required(
                  v ?? '',
                  'Veuillez saisir votre prénom.',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Nom'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.familyName],
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: (v) =>
                    Validators.required(v ?? '', 'Veuillez saisir votre nom.'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (v) => AuthViewModel.validateEmail(v ?? ''),
                scrollPadding: const EdgeInsets.only(bottom: 120),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Mot de passe',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: AuthViewModel.validatePassword,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmation,
                label: 'Confirmation du mot de passe',
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    AuthViewModel.validateConfirmation(_password.text, v),
                onSubmitted: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              LoadingButton(
                label: auth.isSubmitting
                    ? 'Création du compte…'
                    : 'Créer mon compte',
                isBusy: auth.isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SocialSignInButtons(),
        const SizedBox(height: AppSpacing.xl),
        AuthSwitchLink(
          question: 'Déjà un compte ?',
          action: 'Se connecter',
          onPressed: auth.isSubmitting
              ? null
              : () {
                  ref.read(authViewModelProvider.notifier).clearError();
                  context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.login);
                },
        ),
      ],
    );
  }
}
