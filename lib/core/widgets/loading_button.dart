import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

// Bouton principal : l'icône laisse place à un indicateur pendant une
// action, et le bouton est désactivé. `label` peut décrire l'étape en
// cours (« Enregistrement… »).
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final leading = isBusy
        ? const ButtonSpinner()
        : icon == null
        ? null
        : Icon(icon);
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// Indicateur d'activité à la taille d'une icône de bouton.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
