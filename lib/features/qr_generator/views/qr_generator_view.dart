import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../auth/models/app_user.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_generator_view_model.dart';
import '../widgets/qr_type_card.dart';

// Écran d'accueil : l'utilisateur choisit le type de QR Code à créer.
class QrGeneratorView extends ConsumerWidget {
  const QrGeneratorView({super.key});

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.content),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Le menu passe sous le logo si la place manque (texte
                  // agrandi, petit écran).
                  const Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: AppSpacing.xs,
                    children: [BrandMark(), _AccountMenu()],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (firstName != null && firstName.isNotEmpty) ...[
                    Text(
                      'Bonjour, $firstName',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      'Créez votre QR Code\nen quelques secondes.',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choisissez ce que vous souhaitez partager, '
                    'personnalisez-le, puis partagez-le.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Choisissez un type',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeGrid(onSelected: onTypeSelected),
                  const SizedBox(height: AppSpacing.xl),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => context.push(AppRoutes.history),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Voir mes QR Codes enregistrés'),
                    ),
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

// Grille des types : 1, 2 ou 3 colonnes selon la largeur disponible
// rapportée à la taille du texte. Les cartes d'une ligne ont la même
// hauteur.
class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.onSelected});

  // Largeur minimale d'une carte, à taille de texte normale.
  static const double _minCardWidth = 160;

  final ValueChanged<QrType> onSelected;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + AppSpacing.sm) /
                    (_minCardWidth * textScale + AppSpacing.sm))
                .floor()
                .clamp(1, 3);
        const types = QrType.values;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < types.length; start += columns) ...[
              if (start > 0) const SizedBox(height: AppSpacing.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: i < types.length
                            ? QrTypeCard(
                                type: types[i],
                                onTap: () => onSelected(types[i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// Menu du compte : identité, « Mes QR Codes » et déconnexion.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider.select((s) => s.user));
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Mon compte',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      onSelected: (action) => switch (action) {
        _AccountAction.history => context.push(AppRoutes.history),
        _AccountAction.logout =>
          ref.read(authViewModelProvider.notifier).logout(),
      },
      itemBuilder: (context) => [
        if (user != null) ...[
          _ProfileHeader(user: user),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: _AccountAction.history,
          child: ListTile(
            leading: Icon(Icons.qr_code_2_rounded),
            title: Text('Mes QR Codes'),
          ),
        ),
        const PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Se déconnecter'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(user: user),
            const SizedBox(width: AppSpacing.xs),
            const Flexible(child: Text('Mon compte')),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { history, logout }

// Initiales de l'utilisateur dans une pastille.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = [user?.firstName ?? '', user?.lastName ?? '']
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 20,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: initials.isEmpty
            ? const Icon(Icons.person_outline_rounded, size: 20)
            : Text(
                initials,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}

// En-tête du menu : nom et adresse du compte connecté (non cliquable).
class _ProfileHeader extends PopupMenuEntry<_AccountAction> {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  double get height => 72;

  @override
  bool represents(_AccountAction? value) => false;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final name = '${user.firstName} ${user.lastName}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _Avatar(user: user),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                if (user.email case final email?)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
