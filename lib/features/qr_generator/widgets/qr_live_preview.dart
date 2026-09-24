import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../viewmodels/qr_content_view_model.dart';
import 'qr_preview.dart';

// Section « Aperçu » mise à jour pendant la saisie. Isolée pour que seule
// cette section se reconstruise à chaque frappe.
class QrLivePreview extends ConsumerWidget {
  const QrLivePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(livePreviewProvider);
    if (preview == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Aperçu', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
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
