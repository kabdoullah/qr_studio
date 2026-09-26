import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';

// Carte mettant en valeur un QR Code : en-tête facultatif, QR Code (ou
// message d'attente) entouré d'espace, puis légende (nom, type).
class QrPreviewCard extends StatelessWidget {
  const QrPreviewCard({
    super.key,
    required this.child,
    this.header,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final Widget? header;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header case final header?) ...[
              header,
              const SizedBox(height: AppSpacing.lg),
            ],
            child,
            if (title case final title?) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
            if (subtitle case final subtitle?) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
