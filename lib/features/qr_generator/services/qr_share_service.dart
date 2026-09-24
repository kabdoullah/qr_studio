import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
  // l'utilisateur annule.
  Future<bool> savePng(Uint8List png, {required String fileName}) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: png,
      mimeType: _mimeType,
    );
    return uri != null;
  }
}

final qrShareServiceProvider = Provider<QrShareService>(
  (ref) => const QrShareService(),
);
