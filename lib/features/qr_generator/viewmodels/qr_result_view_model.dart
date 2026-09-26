import 'dart:developer' as developer;
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/qr_code_data.dart';
import '../services/qr_export_service.dart';
import '../services/qr_share_service.dart';

part 'qr_result_view_model.g.dart';

// Action d'export en cours sur l'écran résultat (`null` : aucune).
enum QrResultAction { download, share }

// Gère le téléchargement et le partage du QR Code généré.
@Riverpod(keepAlive: true)
class QrResultViewModel extends _$QrResultViewModel {
  static const String savedMessage = 'QR Code enregistré.';
  static const String saveFailedMessage =
      "Impossible d'enregistrer le QR Code.\nVeuillez réessayer.";
  static const String shareFailedMessage =
      'Impossible de partager le QR Code.\nVeuillez réessayer.';

  @override
  QrResultAction? build() => null;

  // Enregistre l'image PNG. Renvoie le message à afficher, ou `null` si
  // l'utilisateur a annulé.
  Future<String?> download(QrCodeData data) {
    return _run(QrResultAction.download, saveFailedMessage, () async {
      final png = await ref.read(qrExportServiceProvider).exportPng(data);
      final saved = await ref
          .read(qrShareServiceProvider)
          .savePng(png, fileName: data.type.fileName);
      return saved ? savedMessage : null;
    });
  }

  // Partage l'image PNG. Pour un contenu en ligne (CV, image de carte,
  // page de réseaux sociaux), le lien accompagne l'image. Renvoie
  // un message d'erreur, ou `null` si tout s'est bien passé.
  Future<String?> share(QrCodeData data, {Rect? origin}) {
    return _run(QrResultAction.share, shareFailedMessage, () async {
      final png = await ref.read(qrExportServiceProvider).exportPng(data);
      await ref
          .read(qrShareServiceProvider)
          .sharePng(
            png,
            fileName: data.type.fileName,
            text: data.isOnlineLink ? data.payload : null,
            origin: origin,
          );
      return null;
    });
  }

  // Exécute une action à la fois et traduit les erreurs techniques en
  // message compréhensible.
  Future<String?> _run(
    QrResultAction action,
    String failureMessage,
    Future<String?> Function() body,
  ) async {
    if (state != null) return null;
    state = action;
    try {
      return await body();
    } catch (error, stackTrace) {
      developer.log(
        'Échec de l’action ${action.name}',
        name: 'QrResultViewModel',
        error: error,
        stackTrace: stackTrace,
      );
      return failureMessage;
    } finally {
      state = null;
    }
  }
}
