import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/no_retry.dart';
import '../models/business_card_data.dart';
import '../services/business_card_directory_service.dart';
import 'qr_content_state.dart';

part 'saved_cards_view_model.g.dart';

// Liste et recherche des cartes partagées. Recréé à chaque ouverture de
// l'écran ; pas de nouvel essai automatique : l'utilisateur voit l'erreur
// et choisit de réessayer.
@Riverpod(retry: noRetry)
class SavedCardsViewModel extends _$SavedCardsViewModel {
  static const String loadFailedMessage =
      'Impossible de charger les cartes.\nVérifiez votre connexion.';

  // Délai après la dernière frappe avant de lancer la recherche.
  static const Duration searchDelay = Duration(milliseconds: 350);

  Timer? _searchTimer;
  String _query = '';
  // Seule la réponse à la dernière recherche est affichée.
  int _requestId = 0;

  @override
  Future<List<SavedBusinessCard>> build() {
    ref.onDispose(() => _searchTimer?.cancel());
    return _fetch(_query);
  }

  void updateQuery(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, () => _load(query));
  }

  Future<void> retry() => _load(_query);

  Future<void> _load(String query) async {
    _query = query;
    final requestId = ++_requestId;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _fetch(query));
    if (ref.mounted && requestId == _requestId) state = result;
  }

  Future<List<SavedBusinessCard>> _fetch(String query) async {
    final directory = ref.read(businessCardDirectoryProvider);
    if (directory == null) throw StateError('Aucun serveur configuré.');
    try {
      return await directory.search(query);
    } catch (error, stackTrace) {
      developer.log(
        'Échec du chargement des cartes',
        name: 'SavedCardsViewModel',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

// Publication d'une carte dans l'annuaire partagé. L'état indique si une
// publication est en cours.
@Riverpod(keepAlive: true)
class CardPublishViewModel extends _$CardPublishViewModel {
  static const String publishedMessage =
      'Carte enregistrée. Elle est maintenant visible par tous.';
  static const String invalidMessage =
      'Renseignez au moins votre prénom et votre nom.';
  static const String tooManyMessage = "Trop d'envois. Réessayez plus tard.";
  static const String failedMessage =
      "Impossible d'enregistrer la carte.\nVérifiez votre connexion.";

  @override
  bool build() => false;

  // Renvoie le message à afficher, ou `null` si une publication est déjà
  // en cours.
  Future<String?> publish(BusinessCardData card) async {
    if (state) return null;
    if (!QrContentState.isValidBusinessCard(card)) return invalidMessage;
    final directory = ref.read(businessCardDirectoryProvider);
    if (directory == null) return failedMessage;

    state = true;
    try {
      await directory.publish(card);
      return publishedMessage;
    } catch (error, stackTrace) {
      developer.log(
        'Échec de la publication de la carte',
        name: 'CardPublishViewModel',
        error: error,
        stackTrace: stackTrace,
      );
      final tooMany =
          error is ApiException && error.kind == ApiErrorKind.tooManyRequests;
      return tooMany ? tooManyMessage : failedMessage;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
