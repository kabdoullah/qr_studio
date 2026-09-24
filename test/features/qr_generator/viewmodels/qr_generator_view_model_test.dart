import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('Aucun type sélectionné au départ', () {
    expect(container.read(qrGeneratorViewModelProvider), isNull);
  });

  test('selectQrType mémorise le type choisi', () {
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.cv);

    expect(container.read(qrGeneratorViewModelProvider), QrType.cv);
  });

  test('reset efface la sélection', () {
    final viewModel = container.read(qrGeneratorViewModelProvider.notifier);
    viewModel.selectQrType(QrType.text);
    viewModel.reset();

    expect(container.read(qrGeneratorViewModelProvider), isNull);
  });
}
