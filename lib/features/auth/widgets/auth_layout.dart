import 'package:flutter/material.dart';

import '../../../core/widgets/error_message.dart';

// Mise en page commune à la connexion et à l'inscription : en-tête QR
// Studio, formulaire centré et message d'erreur éventuel.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.errorMessage,
    this.showBackButton = false,
  });

  static const double _maxWidth = 440;

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? errorMessage;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: showBackButton ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'QR Studio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.headlineMedium),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (errorMessage case final message?) ...[
                      ErrorMessage(message),
                      const SizedBox(height: 16),
                    ],
                    ...children,
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
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: TextButton(
            onPressed: () => setState(() => _obscured = !_obscured),
            child: Text(
              _obscured ? 'Afficher' : 'Masquer',
              semanticsLabel: _obscured
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
            ),
          ),
        ),
      ),
      validator: (value) => widget.validator(value ?? ''),
      scrollPadding: const EdgeInsets.only(bottom: 120),
    );
  }
}

// Bouton principal, avec indicateur pendant l'envoi.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      child: isBusy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(busyLabel)),
              ],
            )
          : Text(label),
    );
  }
}
