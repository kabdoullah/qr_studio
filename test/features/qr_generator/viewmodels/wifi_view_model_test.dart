import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/wifi_qr_data.dart';
import 'package:qr_studio/features/qr_generator/services/qr_code_service.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_generator_view_model.dart';

import '../../../helpers/fake_services.dart';

// Wi-Fi : le QR Code contient les informations de connexion ; le réseau
// est aussi enregistré sur le compte.
void main() {
  late ProviderContainer container;
  late FakeQrCodeService service;

  QrContentViewModel viewModel() =>
      container.read(qrContentViewModelProvider.notifier);
  QrContentState state() => container.read(qrContentViewModelProvider);

  setUp(() {
    service = FakeQrCodeService();
    container = ProviderContainer(
      overrides: [qrCodeServiceProvider.overrideWithValue(service)],
    );
    container
        .read(qrGeneratorViewModelProvider.notifier)
        .selectQrType(QrType.wifi);
  });
  tearDown(() => container.dispose());

  void fill({
    String ssid = 'Maison',
    String password = 'secret-wifi',
    WifiSecurity security = WifiSecurity.wpa2,
  }) {
    viewModel().updateWifi(
      (w) => w.copyWith(ssid: ssid, password: password, security: security),
    );
  }

  group('validation', () {
    test('nom du réseau obligatoire, 32 caractères maximum', () {
      expect(QrContentState.validateWifiSsid(' '), isNotNull);
      expect(QrContentState.validateWifiSsid('x' * 33), isNotNull);
      expect(QrContentState.validateWifiSsid('Maison'), isNull);
    });

    test('mot de passe selon la sécurité', () {
      expect(
        QrContentState.validateWifiPassword('', WifiSecurity.wpa2),
        'Veuillez saisir le mot de passe.',
      );
      expect(
        QrContentState.validateWifiPassword('court', WifiSecurity.wpa3),
        isNotNull,
      );
      expect(
        QrContentState.validateWifiPassword('12345678', WifiSecurity.wpa),
        isNull,
      );
      expect(
        QrContentState.validateWifiPassword('abc', WifiSecurity.wep),
        isNull,
      );
      expect(
        QrContentState.validateWifiPassword('', WifiSecurity.none),
        isNull,
      );
    });
  });

  test('génère le QR Wi-Fi standard et enregistre le réseau', () async {
    fill();

    final result = await viewModel().generateQr();

    expect(result?.payload, 'WIFI:T:WPA;S:Maison;P:secret-wifi;;');
    // Le lien n'est ni affiché ni joint au partage.
    expect(result?.isOnlineLink, isFalse);
    final created = service.created.single;
    expect(created.title, 'Wi-Fi Maison');
    expect(created.content, {
      'ssid': 'Maison',
      'security': 'WPA2',
      'password': 'secret-wifi',
      'hidden': false,
    });
  });

  test('réseau ouvert : le mot de passe saisi n’est pas envoyé', () async {
    fill(ssid: 'Libre', security: WifiSecurity.none);

    final result = await viewModel().generateQr();

    expect(result?.payload, 'WIFI:T:nopass;S:Libre;;');
    expect(service.created.single.content['password'], '');
  });

  test('mot de passe trop court : rien n’est enregistré', () async {
    fill(password: 'court');

    expect(await viewModel().generateQr(), isNull);
    expect(service.created, isEmpty);
    expect(state().showErrorsFor, contains(QrType.wifi));
  });

  test('aperçu en direct du QR Wi-Fi', () {
    expect(container.read(livePreviewProvider)?.payload, isNull);

    fill();

    expect(
      container.read(livePreviewProvider)?.payload,
      'WIFI:T:WPA;S:Maison;P:secret-wifi;;',
    );
  });

  test('ouvrir un QR Wi-Fi enregistré retrouve la saisie', () async {
    fill();
    final saved = (await viewModel().generateQr(), service.items.single).$2;
    viewModel().startOver();

    final result = viewModel().openSaved(saved);

    expect(state().wifi.ssid, 'Maison');
    expect(state().wifi.password, 'secret-wifi');
    expect(result.payload, 'WIFI:T:WPA;S:Maison;P:secret-wifi;;');
    expect(container.read(qrGeneratorViewModelProvider), QrType.wifi);
  });
}
