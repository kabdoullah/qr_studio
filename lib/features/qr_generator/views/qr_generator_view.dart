import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../auth/models/app_user.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../../auth/widgets/delete_account_dialog.dart';
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
                    children: [BrandMark(), _SettingsMenu()],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
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

// Paramètres : identité, « Mes QR Codes », puis création de compte et
// connexion (facultatives) sans compte, déconnexion et suppression pour un
// compte enregistré, et la politique de confidentialité.
class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider.select((s) => s.user));
    final registered = ref.watch(
      authViewModelProvider.select((s) => s.isAuthenticated),
    );
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Paramètres',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      onSelected: (action) => switch (action) {
        _AccountAction.history => context.push(AppRoutes.history),
        _AccountAction.register => context.push(AppRoutes.register),
        _AccountAction.login => context.push(AppRoutes.login),
        _AccountAction.logout =>
          ref.read(authViewModelProvider.notifier).logout(),
        _AccountAction.deleteAccount => _deleteAccount(context),
        _AccountAction.privacy => _openPrivacyPolicy(context),
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
        if (!registered) ...const [
          PopupMenuItem(
            value: _AccountAction.register,
            child: ListTile(
              leading: Icon(Icons.person_add_alt_rounded),
              title: Text('Créer un compte'),
            ),
          ),
          PopupMenuItem(
            value: _AccountAction.login,
            child: ListTile(
              leading: Icon(Icons.login_rounded),
              title: Text('Se connecter'),
            ),
          ),
        ] else ...const [
          PopupMenuItem(
            value: _AccountAction.logout,
            child: ListTile(
              leading: Icon(Icons.logout_rounded),
              title: Text('Se déconnecter'),
            ),
          ),
          PopupMenuItem(
            value: _AccountAction.deleteAccount,
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined),
              title: Text('Supprimer mon compte'),
            ),
          ),
        ],
        if (privacyPolicyUri != null) ...const [
          PopupMenuDivider(),
          PopupMenuItem(
            value: _AccountAction.privacy,
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('Politique de confidentialité'),
            ),
          ),
        ],
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: AppSpacing.xs),
              Flexible(child: Text('Paramètres')),
              Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _deleteAccount(BuildContext context) async {
    final message = await showDeleteAccountDialog(context);
    if (message != null && context.mounted) _showMessage(context, message);
  }

  static Future<void> _openPrivacyPolicy(BuildContext context) async {
    final opened = await launchUrl(
      privacyPolicyUri!,
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);
    if (!opened && context.mounted) {
      _showMessage(context, "Impossible d'ouvrir la page. Réessayez.");
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AccountAction { history, register, login, logout, deleteAccount, privacy }

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

// En-tête du menu : nom et adresse du compte, ou « Compte anonyme » (non
// cliquable). Aucune adresse n'est inventée pour un utilisateur anonyme.
class _ProfileHeader extends PopupMenuEntry<_AccountAction> {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  double get height => 88;

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
    final name = user.isAnonymous
        ? 'Utilisateur QR Studio'
        : user.displayName.isNotEmpty
        ? user.displayName
        : 'Mon compte';
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
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
                    style: secondary,
                  ),
                Text(
                  user.isAnonymous ? 'Compte anonyme' : 'Compte synchronisé',
                  style: secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
