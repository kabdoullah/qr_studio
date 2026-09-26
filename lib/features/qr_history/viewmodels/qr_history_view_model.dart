import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../qr_generator/models/saved_qr_code.dart';
import '../../qr_generator/services/qr_code_service.dart';

// « Mes QR Codes » : liste des QR Codes du compte, rechargée à chaque
// ouverture de l'écran.
class QrHistoryViewModel extends AsyncNotifier<List<SavedQrCode>> {
  static const String unavailableMessage =
      "L'historique n'est pas encore disponible.";
  static const String loadFailedMessage =
      'Impossible de charger vos QR Codes.\n'
      'Vérifiez votre connexion et réessayez.';
  static const String deletedMessage = 'QR Code supprimé.';
  static const String deleteFailedMessage =
      'Impossible de supprimer le QR Code.\nVeuillez réessayer.';

  @override
  Future<List<SavedQrCode>> build() async {
    final service = ref.watch(qrCodeServiceProvider);
    if (service == null) throw const QrHistoryException(unavailableMessage);
    try {
      return await service.list();
    } catch (error, stackTrace) {
      _log('Échec du chargement', error, stackTrace);
      throw QrHistoryException(
        error is ApiException && error.kind != ApiErrorKind.server
            ? error.message
            : loadFailedMessage,
      );
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future.catchError((_) => <SavedQrCode>[]);
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
    final items = state.value;
    if (items != null) {
      state = AsyncData([
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

// Erreur de chargement, avec son message pour l'utilisateur.
class QrHistoryException implements Exception {
  const QrHistoryException(this.message);

  final String message;

  @override
  String toString() => 'QrHistoryException: $message';
}

final qrHistoryViewModelProvider =
    AsyncNotifierProvider.autoDispose<QrHistoryViewModel, List<SavedQrCode>>(
      QrHistoryViewModel.new,
      retry: (_, _) => null,
    );
