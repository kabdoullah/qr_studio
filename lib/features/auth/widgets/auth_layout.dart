import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/visibility_toggle.dart';

// Mise en page commune à la connexion et à l'inscription : logo, titre,
// formulaire centré et message d'erreur éventuel. Sur grand écran, le
// formulaire est posé sur une carte.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.errorMessage,
    this.showBackButton = false,
  });

  // Largeur à partir de laquelle le formulaire est présenté sur une carte.
  static const double _cardBreakpoint = 600;

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? errorMessage;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: BrandMark(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (errorMessage case final message?) ...[
            ErrorMessage(message),
            const SizedBox(height: AppSpacing.md),
          ],
          ...children,
        ],
      ),
    );

    return Scaffold(
      appBar: showBackButton ? AppBar() : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _cardBreakpoint;
            return Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: wide ? AppSpacing.huge : AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppLayout.narrow),
                  child: wide
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: content,
                          ),
                        )
                      : content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Lien secondaire en bas de formulaire : « Pas encore de compte ? Créer
// un compte ».
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

// Champ mot de passe avec un bouton texte « Afficher » / « Masquer ».
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    required this.autofillHints,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String value) validator;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: VisibilityToggle(
          obscured: _obscured,
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: (value) => widget.validator(value ?? ''),
      scrollPadding: const EdgeInsets.only(bottom: 120),
    );
  }
}
