import 'package:flutter/material.dart';

// Bouton « Afficher » / « Masquer » d'un champ mot de passe, avec icône
// et libellé explicite.
class VisibilityToggle extends StatelessWidget {
  const VisibilityToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
        ),
        label: Text(
          obscured ? 'Afficher' : 'Masquer',
          semanticsLabel: obscured
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
        ),
      ),
    );
  }
}
