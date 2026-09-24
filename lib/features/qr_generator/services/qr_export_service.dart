import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../models/qr_code_data.dart';

// Rendu du QR Code en image PNG.
class QrExportService {
  const QrExportService();

  // 1024 px : net sur WhatsApp et par email, et environ 8,7 cm à 300 dpi
  // pour l'impression.
  static const int defaultSize = 1024;

  // Génère l'image PNG (fond et marge inclus) du QR Code.
  Future<Uint8List> exportPng(QrCodeData data, {int size = defaultSize}) async {
    final qrCode = QrCode.fromData(
      data: data.payload,
      errorCorrectLevel: data.style.errorCorrectLevel,
    );
    final bytes = await QrImage(qrCode).toImageAsBytes(
      size: size,
      format: ui.ImageByteFormat.png,
      decoration: data.style.toDecoration(forExport: true),
    );
    if (bytes == null) throw StateError('Encodage PNG impossible.');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }
}

final qrExportServiceProvider = Provider<QrExportService>(
  (ref) => const QrExportService(),
);
