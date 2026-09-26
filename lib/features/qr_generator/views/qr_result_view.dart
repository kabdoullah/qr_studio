import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/loading_button.dart';
import '../models/qr_code_data.dart';
import '../viewmodels/qr_content_view_model.dart';
import '../viewmodels/qr_result_view_model.dart';
import '../widgets/qr_preview.dart';
import '../widgets/qr_preview_card.dart';

// Écran final : le QR Code généré, mis en valeur, et les actions possibles.
class QrResultView extends ConsumerWidget {
  const QrResultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(
      qrContentViewModelProvider.select((s) => s.result),
    );
    // L'état est effacé pendant la transition de « Créer un nouveau ».
    if (result == null) return const Scaffold();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.narrow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SuccessBadge(),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      result.type.readyMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Scannez-le, partagez-le ou téléchargez-le.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  QrPreviewCard(
                    title: result.file?.name ?? result.type.title,
                    child: QrPreview(data: result.payload, style: result.style),
                  ),
                  // Lien encodé, pour un contenu en ligne.
                  if (result.isOnlineLink) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      result.payload,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _ExportButtons(result: result),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: () {
                      context.go(AppRoutes.home);
                      ref.read(qrContentViewModelProvider.notifier).startOver();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer un nouveau QR Code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Coche de succès, qui apparaît brièvement (fondu et zoom).
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final success = AppStatusColors.of(context).success;
    return ExcludeSemantics(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppDurations.normal,
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(scale: 0.6 + 0.4 * value, child: child),
          ),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 32, color: success),
          ),
        ),
      ),
    );
  }
}

// Boutons « Partager » (action principale) et « Télécharger ». Isolés pour que seul ce bloc se
// reconstruise pendant l'export.
class _ExportButtons extends ConsumerWidget {
  const _ExportButtons({required this.result});

  final QrCodeData result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(qrResultViewModelProvider);
    final viewModel = ref.read(qrResultViewModelProvider.notifier);

    void showMessage(String? message) {
      if (message == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    Widget icon(QrResultAction action, IconData data) =>
        pending == action ? const ButtonSpinner() : Icon(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Builder : fournit la position du bouton pour la feuille de
        // partage sur iPad.
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: pending != null
                ? null
                : () async {
                    final box = buttonContext.findRenderObject() as RenderBox?;
                    final origin = box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size;
                    showMessage(await viewModel.share(result, origin: origin));
                  },
            icon: icon(QrResultAction.share, Icons.ios_share_rounded),
            label: const Text('Partager'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: pending != null
              ? null
              : () async => showMessage(await viewModel.download(result)),
          icon: icon(QrResultAction.download, Icons.download_rounded),
          label: const Text('Télécharger'),
        ),
      ],
    );
  }
}
