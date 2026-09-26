import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_generator_view_model.dart';
import '../widgets/qr_type_card.dart';

// Écran d'accueil : l'utilisateur choisit le type de QR Code à créer.
class QrGeneratorView extends ConsumerWidget {
  const QrGeneratorView({super.key});

  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final firstName = ref.watch(
      authViewModelProvider.select((s) => s.user?.firstName.trim()),
    );

    void onTypeSelected(QrType type) {
      ref.read(qrGeneratorViewModelProvider.notifier).selectQrType(type);
      context.push(AppRoutes.content);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Le menu passe sous le titre si la place manque (texte
                  // agrandi, petit écran).
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'QR Studio',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      const _AccountMenu(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (firstName != null && firstName.isNotEmpty) ...[
                    Text(
                      'Bonjour, $firstName',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Créez votre QR Code\nsimplement et rapidement.',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choisissez ce que vous souhaitez partager.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (final type in QrType.values) ...[
                    QrTypeCard(type: type, onTap: () => onTypeSelected(type)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Menu du compte : « Mes QR Codes » et déconnexion.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Mon compte',
      onSelected: (action) => switch (action) {
        _AccountAction.history => context.push(AppRoutes.history),
        _AccountAction.logout =>
          ref.read(authViewModelProvider.notifier).logout(),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AccountAction.history,
          child: ListTile(
            leading: Icon(Icons.history_rounded),
            title: Text('Mes QR Codes'),
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Se déconnecter'),
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined),
            SizedBox(width: 6),
            Flexible(child: Text('Mon compte')),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { history, logout }
