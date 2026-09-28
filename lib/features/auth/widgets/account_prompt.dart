import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../viewmodels/auth_view_model.dart';

// Mention discrète, en bas de « Mes QR Codes », pour l'utilisateur
// anonyme : ses QR Codes sont liés à cet appareil, un compte (facultatif)
// permet de les retrouver ailleurs. L'application ne pousse jamais à se
// connecter : ni carte, ni fenêtre, ni rappel.
class AccountPrompt extends ConsumerWidget {
  const AccountPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anonymous = ref.watch(
      authViewModelProvider.select((s) => s.isAnonymous),
    );
    if (!anonymous) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Vos QR Codes sont enregistrés sur cet appareil.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.register),
            child: const Text('Les retrouver sur un autre appareil'),
          ),
        ],
      ),
    );
  }
}
