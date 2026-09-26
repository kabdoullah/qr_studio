import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_dimens.dart';
import '../viewmodels/qr_content_view_model.dart';
import 'qr_preview.dart';
import 'qr_preview_card.dart';

// Carte « Aperçu » mise à jour pendant la saisie. Isolée pour que seule
// cette carte se reconstruise à chaque frappe.
class QrLivePreview extends ConsumerWidget {
  const QrLivePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(livePreviewProvider);
    if (preview == null) return const SizedBox.shrink();

    return QrPreviewCard(
      header: const _Header(),
      child: AnimatedSwitcher(
        duration: AppDurations.normal,
        child: switch (preview) {
          LivePreview(:final payload?) => QrPreview(
            key: const ValueKey('qr'),
            data: payload,
          ),
          LivePreview(:final message) => _Placeholder(
            key: ValueKey(message),
            message: message ?? '',
          ),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Titre et pastille passent l'un sous l'autre si le texte est agrandi.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text('Aperçu', style: theme.textTheme.titleMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs / 2,
          ),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'En direct',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: AppSpacing.huge,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
