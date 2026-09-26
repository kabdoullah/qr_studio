import 'package:flutter/material.dart';

import '../../app/theme/app_dimens.dart';

// Titre de section, annoncé comme en-tête aux lecteurs d'écran, avec une
// précision facultative (« Facultatif », « 2 / 10 »…) et un séparateur
// discret au-dessus pour découper les longs formulaires.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.description,
    this.divider = false,
  });

  final String title;
  final String? subtitle;
  final String? description;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(
        top: divider ? AppSpacing.xs : AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (divider) ...[
            const Divider(),
            const SizedBox(height: AppSpacing.xl),
          ],
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                text: title,
                style: theme.textTheme.titleMedium,
                children: [
                  if (subtitle != null)
                    TextSpan(
                      text: '  ·  $subtitle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
