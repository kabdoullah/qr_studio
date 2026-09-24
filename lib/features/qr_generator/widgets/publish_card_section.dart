import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/qr_content_view_model.dart';
import '../viewmodels/saved_cards_view_model.dart';

// Publication de la carte saisie dans l'annuaire partagé, après
// confirmation : la carte devient visible par tous les utilisateurs.
class PublishCardSection extends ConsumerWidget {
  const PublishCardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publishing = ref.watch(cardPublishViewModelProvider);
    final theme = Theme.of(context);

    Future<void> publish() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const _ConfirmDialog(),
      );
      if (confirmed != true) return;
      final card = ref.read(qrContentViewModelProvider).businessCard;
      final message = await ref
          .read(cardPublishViewModelProvider.notifier)
          .publish(card);
      if (message == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: publishing ? null : publish,
            icon: publishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.public_rounded),
            label: const Text('Enregistrer dans les cartes partagées'),
          ),
          const SizedBox(height: 8),
          Text(
            'Une carte enregistrée est visible par tous les utilisateurs '
            'de QR Studio.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rendre cette carte publique ?'),
      content: const Text(
        'Tous les utilisateurs de QR Studio pourront voir ces coordonnées. '
        "La carte ne pourra pas être supprimée depuis l'application.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Publier'),
        ),
      ],
    );
  }
}
