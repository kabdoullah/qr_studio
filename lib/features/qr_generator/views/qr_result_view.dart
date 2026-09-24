import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../models/qr_code_data.dart';
import '../viewmodels/qr_content_view_model.dart';
import '../viewmodels/qr_result_view_model.dart';
import '../widgets/qr_preview.dart';

// Écran final : le QR Code généré et les actions possibles.
class QrResultView extends ConsumerWidget {
  const QrResultView({super.key});

  static const double _maxContentWidth = 480;

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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      result.type.readyMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 32),
                  QrPreview(data: result.payload, style: result.style),
                  const SizedBox(height: 20),
                  Text(
                    result.file?.name ?? result.type.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  // Lien encodé, pour un fichier partagé.
                  if (result.file != null) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      result.payload,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _ExportButtons(result: result),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      context.go(AppRoutes.home);
                      ref.read(qrContentViewModelProvider.notifier).startOver();
                    },
                    child: const Text('Créer un nouveau QR Code'),
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

// Boutons « Télécharger » et « Partager ». Isolés pour que seul ce bloc se
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

    Widget icon(QrResultAction action, IconData data) => pending == action
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: pending != null
              ? null
              : () async => showMessage(await viewModel.download(result)),
          icon: icon(QrResultAction.download, Icons.download_rounded),
          label: const Text('Télécharger'),
        ),
        const SizedBox(height: 12),
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
      ],
    );
  }
}
