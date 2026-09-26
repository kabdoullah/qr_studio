import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/widgets/error_message.dart';
import '../../qr_generator/models/saved_qr_code.dart';
import '../../qr_generator/viewmodels/qr_content_view_model.dart';
import '../../qr_generator/viewmodels/qr_result_view_model.dart';
import '../viewmodels/qr_history_view_model.dart';

// « Mes QR Codes » : ouvrir, modifier, partager ou supprimer.
class QrHistoryView extends ConsumerWidget {
  const QrHistoryView({super.key});

  static const double _maxContentWidth = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(qrHistoryViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes QR Codes')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: switch (history) {
              AsyncData(value: final items) when items.isEmpty =>
                const _Message(
                  'Aucun QR Code pour le moment.\n'
                  'Ceux que vous créez apparaîtront ici.',
                ),
              AsyncData(value: final items) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(qrHistoryViewModelProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _QrCodeTile(qr: items[index]),
                ),
              ),
              AsyncError(:final error) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErrorMessage(
                      error is QrHistoryException
                          ? error.message
                          : QrHistoryViewModel.loadFailedMessage,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(qrHistoryViewModelProvider.notifier)
                          .reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _QrCodeTile extends ConsumerWidget {
  const _QrCodeTile({required this.qr});

  final SavedQrCode qr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentViewModel = ref.read(qrContentViewModelProvider.notifier);

    void showMessage(String? message) {
      if (message == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> delete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _DeleteDialog(title: qr.title),
      );
      if (confirmed != true) return;
      showMessage(
        await ref.read(qrHistoryViewModelProvider.notifier).delete(qr),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(qr.type.icon, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(qr.title, style: theme.textTheme.titleMedium),
                      Text(
                        qr.type.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    contentViewModel.openSaved(qr);
                    context.push(AppRoutes.result);
                  },
                  child: Text('Ouvrir', semanticsLabel: 'Ouvrir ${qr.title}'),
                ),
                TextButton(
                  onPressed: () {
                    contentViewModel.openSaved(qr);
                    context.push(AppRoutes.content);
                  },
                  child: Text(
                    'Modifier',
                    semanticsLabel: 'Modifier ${qr.title}',
                  ),
                ),
                Builder(
                  builder: (buttonContext) => TextButton(
                    onPressed: () async {
                      final box =
                          buttonContext.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size;
                      final data = contentViewModel.resultFor(qr);
                      showMessage(
                        await ref
                            .read(qrResultViewModelProvider.notifier)
                            .share(data, origin: origin),
                      );
                    },
                    child: Text(
                      'Partager',
                      semanticsLabel: 'Partager ${qr.title}',
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  onPressed: delete,
                  child: Text(
                    'Supprimer',
                    semanticsLabel: 'Supprimer ${qr.title}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer ce QR Code ?'),
      content: Text(
        '« $title » sera supprimé. Les QR Codes déjà imprimés ou partagés '
        'ne mèneront plus à rien.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
