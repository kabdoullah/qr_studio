import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../../qr_generator/models/saved_qr_code.dart';
import '../../qr_generator/services/qr_code_service.dart';
import '../services/qr_history_cache.dart';

part 'qr_history_view_model.g.dart';

// État de « Mes QR Codes ».
class QrHistoryState {
  const QrHistoryState({
    this.items,
    this.isRevalidating = false,
    this.errorMessage,
  });

  // Dernière liste connue ; `null` tant qu'aucun chargement n'a abouti.
  final List<SavedQrCode>? items;
  // Rechargement en cours (la liste connue reste affichée).
  final bool isRevalidating;
  // Échec du dernier chargement, pour l'utilisateur. Avec `items`, la liste
  // affichée est celle d'avant l'échec.
  final String? errorMessage;

  bool get hasItems => items != null;

  QrHistoryState copyWith({
    List<SavedQrCode>? items,
    bool? isRevalidating,
    String? Function()? errorMessage,
  }) => QrHistoryState(
    items: items ?? this.items,
    isRevalidating: isRevalidating ?? this.isRevalidating,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );
}

// « Mes QR Codes » en stale-while-revalidate : la dernière liste connue
// s'affiche aussitôt, puis est rechargée en arrière-plan à chaque ouverture
// de l'écran (`revalidate`). Au premier affichage de la session, elle vient
// du cache chiffré sur l'appareil (`QrHistoryCache`), réécrit après chaque
// chargement ou modification. État et cache sont propres au compte
// connecté ; la déconnexion efface le cache (`app.dart`).
@Riverpod(keepAlive: true)
class QrHistoryViewModel extends _$QrHistoryViewModel {
  static const String unavailableMessage =
      "L'historique n'est pas encore disponible.";
  static const String loadFailedMessage =
      'Impossible de charger vos QR Codes.\n'
      'Vérifiez votre connexion et réessayez.';
  static const String deletedMessage = 'QR Code supprimé.';
  static const String deleteFailedMessage =
      'Impossible de supprimer le QR Code.\nVeuillez réessayer.';

  // Incrémenté à chaque modification locale et changement de compte : une
  // réponse partie avant est périmée et n'est pas appliquée.
  int _version = 0;
  Future<void>? _revalidation;
  String? _userId;

  @override
  QrHistoryState build() {
    _userId = ref.watch(authViewModelProvider.select((s) => s.user?.id));
    _version++;
    _revalidation = null;
    return const QrHistoryState();
  }

  // Recharge la liste depuis le serveur, sans masquer celle déjà connue.
  // Les appels simultanés partagent le même chargement.
  Future<void> revalidate() =>
      _revalidation ??= _revalidate().whenComplete(() => _revalidation = null);

  Future<void> _revalidate() async {
    final service = ref.read(qrCodeServiceProvider);
    if (service == null) {
      state = state.copyWith(errorMessage: () => unavailableMessage);
      return;
    }
    final version = _version;
    state = state.copyWith(isRevalidating: true, errorMessage: () => null);
    await _showCached(version);
    try {
      final items = await service.list();
      if (_isCurrent(version)) {
        state = QrHistoryState(items: items);
        _writeCache(items);
      }
    } catch (error, stackTrace) {
      _log('Échec du chargement', error, stackTrace);
      if (_isCurrent(version)) {
        state = state.copyWith(
          isRevalidating: false,
          errorMessage: () =>
              error is ApiException && error.kind != ApiErrorKind.server
              ? error.message
              : loadFailedMessage,
        );
      }
    } finally {
      // Réponse périmée : la modification locale fait foi, un prochain
      // chargement confirmera.
      if (ref.mounted && state.isRevalidating && !_isCurrent(version)) {
        state = state.copyWith(isRevalidating: false);
      }
    }
  }

  bool _isCurrent(int version) => ref.mounted && version == _version;

  // Premier affichage de la session : la liste enregistrée sur l'appareil,
  // en attendant le serveur.
  Future<void> _showCached(int version) async {
    final userId = _userId;
    if (state.hasItems || userId == null) return;
    final cached = await ref.read(qrHistoryCacheProvider).read(userId);
    if (cached != null && _isCurrent(version) && !state.hasItems) {
      state = state.copyWith(items: cached);
    }
  }

  void _writeCache(List<SavedQrCode> items) {
    final userId = _userId;
    // Jamais pour un compte qui n'est plus connecté.
    if (userId == null || ref.read(authViewModelProvider).user?.id != userId) {
      return;
    }
    ref.read(qrHistoryCacheProvider).write(userId, items);
  }

  // Liste modifiée localement : affichée et enregistrée.
  void _replaceItems(List<SavedQrCode> items) {
    _version++;
    state = state.copyWith(items: items);
    _writeCache(items);
  }

  // QR Code créé ou modifié ailleurs dans l'application : mis à jour dans
  // la liste connue (en tête s'il est nouveau), sans attendre le serveur.
  void upsert(SavedQrCode saved) {
    final items = state.items;
    if (items == null) return;
    final exists = items.any((item) => item.id == saved.id);
    _replaceItems(
      exists
          ? [for (final item in items) item.id == saved.id ? saved : item]
          : [saved, ...items],
    );
  }

  // Supprime le QR Code ; son adresse publique ne mène plus à rien.
  // Renvoie le message à afficher.
  Future<String> delete(SavedQrCode qr) async {
    final service = ref.read(qrCodeServiceProvider);
    if (service == null) return unavailableMessage;
    try {
      await service.delete(qr.id);
    } on ApiException catch (error) {
      // Déjà supprimé (autre appareil) : le retirer de la liste suffit.
      if (error.kind != ApiErrorKind.notFound) {
        _log('Échec de la suppression', error, StackTrace.current);
        return deleteFailedMessage;
      }
    } catch (error, stackTrace) {
      _log('Échec de la suppression', error, stackTrace);
      return deleteFailedMessage;
    }
    final items = state.items;
    if (items != null) {
      _replaceItems([
        for (final item in items)
          if (item.id != qr.id) item,
      ]);
    }
    return deletedMessage;
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'QrHistoryViewModel',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
