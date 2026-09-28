import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_button.dart';
import '../viewmodels/auth_view_model.dart';

// Confirmation de la suppression du compte (Paramètres). Le dialogue reste
// ouvert pendant la suppression, puis renvoie le message à afficher
// (confirmation ou erreur) ; `null` si l'utilisateur annule.
Future<String?> showDeleteAccountDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DeleteAccountDialog(),
    );

class _DeleteAccountDialog extends ConsumerWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authViewModelProvider.select((s) => s.isSubmitting));

    Future<void> delete() async {
      final message = await ref
          .read(authViewModelProvider.notifier)
          .deleteAccount();
      if (context.mounted) Navigator.of(context).pop(message);
    }

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Supprimer votre compte ?'),
        content: const Text(
          'Votre compte, tous vos QR Codes et les fichiers envoyés seront '
          'supprimés définitivement. Les QR Codes de CV, de réseaux sociaux '
          'ou de carte de visite en image déjà imprimés ou partagés ne '
          'mèneront plus à rien.\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          LoadingButton(
            label: 'Supprimer mon compte',
            isBusy: busy,
            onPressed: delete,
          ),
        ],
      ),
    );
  }
}
