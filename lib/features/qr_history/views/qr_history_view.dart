import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../qr_generator/models/saved_qr_code.dart';
import '../../qr_generator/viewmodels/qr_content_view_model.dart';
import '../../qr_generator/viewmodels/qr_result_view_model.dart';
import '../viewmodels/qr_history_view_model.dart';

// « Mes QR Codes » : ouvrir, modifier, partager ou supprimer. La dernière
// liste connue s'affiche aussitôt ; elle est actualisée à chaque ouverture.
class QrHistoryView extends ConsumerStatefulWidget {
  const QrHistoryView({super.key});

  @override
  ConsumerState<QrHistoryView> createState() => _QrHistoryViewState();
}

class _QrHistoryViewState extends ConsumerState<QrHistoryView> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pas de modification d'état pendant la construction du widget.
    Future.microtask(_revalidate);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _revalidate() =>
      ref.read(qrHistoryViewModelProvider.notifier).revalidate();

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(qrHistoryViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes QR Codes')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.form),
            child: switch (history) {
              QrHistoryState(items: final items?) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hauteur réservée : la liste ne saute pas.
                  SizedBox(
                    height: AppSpacing.xxs,
                    child: history.isRevalidating
                        ? const LinearProgressIndicator(
                            semanticsLabel: 'Actualisation de vos QR Codes',
                          )
                        : null,
                  ),
                  if (history.errorMessage case final message?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.xs,
                        AppSpacing.gutter,
                        0,
                      ),
                      child: ErrorMessage(message),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _revalidate,
                      child: items.isEmpty
                          ? CustomScrollView(
                              slivers: [
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: EmptyState(
                                    icon: Icons.qr_code_2_rounded,
                                    title:
                                        "Vous n'avez encore créé aucun "
                                        'QR Code.',
                                    message:
                                        'Créez votre premier QR Code pour le '
                                        'retrouver ici.',
                                    action: FilledButton.icon(
                                      onPressed: () =>
                                          context.go(AppRoutes.home),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Créer un QR Code'),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _QrCodeList(items: items, search: _search),
                    ),
                  ),
                ],
              ),
              QrHistoryState(errorMessage: final message?) => EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Chargement impossible',
                message: message,
                action: OutlinedButton.icon(
                  onPressed: _revalidate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
              _ => const _LoadingList(),
            },
          ),
        ),
      ),
    );
  }
}

// Recherche (titre ou type) et liste des QR Codes.
class _QrCodeList extends StatelessWidget {
  const _QrCodeList({required this.items, required this.search});

  final List<SavedQrCode> items;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: search,
      builder: (context, value, _) {
        final query = value.text.trim().toLowerCase();
        final visible = query.isEmpty
            ? items
            : [
                for (final qr in items)
                  if (qr.title.toLowerCase().contains(query) ||
                      qr.type.title.toLowerCase().contains(query))
                    qr,
              ];
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Rechercher',
                hintText: 'Titre ou type de QR Code',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: search.clear,
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Aucun QR Code ne correspond à « ${value.text.trim()} ».',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final (index, qr) in visible.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              _QrCodeTile(key: ValueKey(qr.id), qr: qr),
            ],
          ],
        );
      },
    );
  }
}

class _QrCodeTile extends ConsumerWidget {
  const _QrCodeTile({super.key, required this.qr});

  final SavedQrCode qr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentViewModel = ref.read(qrContentViewModelProvider.notifier);
    final details = [
      qr.type.title,
      if (qr.updatedAt case final date?) _formatDate(date),
    ].join(' · ');

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: Row(
                children: [
                  IconBadge(qr.type.icon, accent: qr.type.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          qr.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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

// « Aujourd'hui », « Hier » ou la date au format jj/mm/aaaa.
String _formatDate(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final days = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (days == 0) return "Aujourd'hui";
  if (days == 1) return 'Hier';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

// Premier chargement : silhouettes de cartes plutôt qu'un écran vide.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
    return Semantics(
      label: 'Chargement de vos QR Codes',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  bar(44, 44),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(160, 14),
                        const SizedBox(height: AppSpacing.xs),
                        bar(96, 10),
                      ],
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
