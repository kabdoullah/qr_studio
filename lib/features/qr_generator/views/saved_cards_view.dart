import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/business_card_data.dart';
import '../viewmodels/qr_content_view_model.dart';
import '../viewmodels/saved_cards_view_model.dart';

// Cartes partagées : toucher une carte remplit le formulaire.
class SavedCardsView extends ConsumerStatefulWidget {
  const SavedCardsView({super.key});

  static const double _maxContentWidth = 560;

  @override
  ConsumerState<SavedCardsView> createState() => _SavedCardsViewState();
}

class _SavedCardsViewState extends ConsumerState<SavedCardsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(savedCardsViewModelProvider);
    final viewModel = ref.read(savedCardsViewModelProvider.notifier);
    final query = _search.text.trim();

    void select(SavedBusinessCard card) {
      ref.read(qrContentViewModelProvider.notifier).loadBusinessCard(card.data);
      context.pop();
    }

    void clearSearch() {
      _search.clear();
      viewModel.updateQuery('');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cartes enregistrées')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: SavedCardsView._maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xs,
                    AppSpacing.gutter,
                    AppSpacing.sm,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _search,
                    builder: (context, value, _) => TextField(
                      controller: _search,
                      onChanged: viewModel.updateQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Rechercher',
                        hintText: 'Nom, entreprise, ville…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: clearSearch,
                                tooltip: 'Effacer la recherche',
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: switch (cards) {
                    AsyncData(:final value) when value.isEmpty => EmptyState(
                      icon: Icons.person_search_outlined,
                      title: query.isEmpty
                          ? 'Aucune carte partagée pour le moment.'
                          : 'Aucune carte ne correspond à « $query ».',
                    ),
                    AsyncData(:final value) => _CardList(
                      cards: value,
                      onSelect: select,
                    ),
                    AsyncError() => EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Chargement impossible',
                      message: SavedCardsViewModel.loadFailedMessage,
                      action: OutlinedButton.icon(
                        onPressed: viewModel.retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    ),
                    _ => const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Chargement des cartes',
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.cards, required this.onSelect});

  final List<SavedBusinessCard> cards;
  final ValueChanged<SavedBusinessCard> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: cards.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _CardTile(card: cards[index], onTap: () => onSelect(cards[index])),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});

  final SavedBusinessCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = card.data;
    final colors = Theme.of(context).colorScheme;
    final name = '${data.firstName} ${data.lastName}'.trim();
    final details = [
      data.jobTitle,
      data.company,
      data.city,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final initials = [data.firstName, data.lastName]
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return Card(
      child: ListTile(
        onTap: onTap,
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(initials, semanticsLabel: ''),
        ),
        title: Text(name),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
