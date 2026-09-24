import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../models/qr_type.dart';

// Carte cliquable représentant un type de QR Code sur l'écran d'accueil.
class QrTypeCard extends StatelessWidget {
  const QrTypeCard({super.key, required this.type, required this.onTap});

  final QrType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Fusionne titre, description et action de l'InkWell en un seul bouton
    // pour les lecteurs d'écran.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radius - 4,
                        ),
                      ),
                      child: Icon(
                        type.icon,
                        size: 28,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            type.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
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
