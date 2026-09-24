import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
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
                  Text(
                    'QR Studio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
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
