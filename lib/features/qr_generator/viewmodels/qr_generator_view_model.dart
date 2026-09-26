import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/qr_type.dart';

part 'qr_generator_view_model.g.dart';

// Mémorise le type de QR Code choisi sur l'écran d'accueil.
@Riverpod(keepAlive: true)
class QrGeneratorViewModel extends _$QrGeneratorViewModel {
  @override
  QrType? build() => null;

  void selectQrType(QrType type) => state = type;

  void reset() => state = null;
}
