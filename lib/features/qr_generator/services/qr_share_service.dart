import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'qr_share_service.g.dart';

// Partage et enregistrement de l'image du QR Code.
class QrShareService {
  const QrShareService();

  static const String _mimeType = 'image/png';

  // Dossier temporaire dédié au partage. Il est vidé avant chaque partage
  // plutôt qu'après : l'application destinataire (WhatsApp, Mail…) peut lire
  // le fichier après le retour de la feuille de partage. Au plus une image
  // reste donc en cache, et le système peut la supprimer.
  static Directory get _shareDirectory =>
      Directory('${Directory.systemTemp.path}/qr_studio_share');

  // Ouvre la feuille de partage native avec l'image. `origin` positionne la
  // feuille sur iPad (obligatoire sur cet appareil).
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    // Sur le web, pas de système de fichiers : l'image est partagée depuis
    // la mémoire (Web Share API, feuille de partage d'iOS).
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, name: fileName, mimeType: _mimeType)],
          fileNameOverrides: [fileName],
          text: text,
        ),
      );
      return;
    }

    final directory = _shareDirectory;
    if (directory.existsSync()) await directory.delete(recursive: true);
    await directory.create(recursive: true);

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(png, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeType)],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }

  // Ouvre la boîte « Enregistrer sous » du système. Renvoie `false` si
  // l'utilisateur annule. Sur le web, le navigateur télécharge l'image
  // directement, sans possibilité d'annuler.
  Future<bool> savePng(Uint8List png, {required String fileName}) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: png,
      mimeType: _mimeType,
    );
    return kIsWeb || uri != null;
  }
}

@Riverpod(keepAlive: true)
QrShareService qrShareService(Ref ref) => const QrShareService();
