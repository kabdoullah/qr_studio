import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qr_type.dart';

// Mémorise le type de QR Code choisi sur l'écran d'accueil.
class QrGeneratorViewModel extends Notifier<QrType?> {
  @override
  QrType? build() => null;

  void selectQrType(QrType type) => state = type;

  void reset() => state = null;
}

final qrGeneratorViewModelProvider =
    NotifierProvider<QrGeneratorViewModel, QrType?>(QrGeneratorViewModel.new);
