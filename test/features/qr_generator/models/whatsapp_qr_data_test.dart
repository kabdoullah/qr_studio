import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/whatsapp_qr_data.dart';
import 'package:qr_studio/features/qr_generator/viewmodels/qr_content_state.dart';

void main() {
  const message = 'Bonjour, je viens de scanner votre QR Code.';

  String? url(String phone, [String? message]) =>
      WhatsAppQrData.buildUrl(phoneNumber: phone, message: message);

  group('buildUrl', () {
    test('numéro international avec espaces', () {
      expect(url('+225 07 12 34 56 78'), 'https://wa.me/2250712345678');
    });

    test('numéro sans espaces ni « + »', () {
      expect(url('2250712345678'), 'https://wa.me/2250712345678');
    });

    test('numéro avec séparateurs', () {
      expect(url('+225-07-12-34-56-78'), 'https://wa.me/2250712345678');
      expect(url('+225 (07) 12.34.56/78'), 'https://wa.me/2250712345678');
      expect(url('00225 07 12 34 56 78'), 'https://wa.me/2250712345678');
    });

    test('message encodé, restitué tel quel une fois décodé', () {
      final result = url('+225 07 12 34 56 78', message)!;
      final uri = Uri.parse(result);

      expect(uri.host, 'wa.me');
      expect(uri.path, '/2250712345678');
      expect(result, contains('text='));
      expect(result, isNot(contains(' ')));
      expect(
        result,
        'https://wa.me/2250712345678'
        '?text=Bonjour%2C%20je%20viens%20de%20scanner%20votre%20QR%20Code.',
      );
      expect(uri.queryParameters['text'], message);
    });

    test('accents, emojis, retours à la ligne et « & » sont conservés', () {
      const text = 'Café & thé ?\nÀ bientôt 😀 #1 +33';
      final uri = Uri.parse(url('+33 6 12 34 56 78', text)!);

      expect(uri.queryParameters.keys, ['text']);
      expect(uri.queryParameters['text'], text);
    });

    test('message vide ou blanc : aucun paramètre text', () {
      expect(url('+225 07 12 34 56 78', ''), 'https://wa.me/2250712345678');
      expect(url('+225 07 12 34 56 78', '   '), 'https://wa.me/2250712345678');
      expect(url('+225 07 12 34 56 78'), isNot(contains('?text=')));
    });

    test('numéro vide ou invalide : aucun lien', () {
      expect(url(''), isNull);
      expect(url('abc'), isNull);
      expect(url('+225 07 12 abc'), isNull);
      expect(url('+ - ( )'), isNull);
      expect(url('+12345'), isNull); // trop court
      expect(url('+1234567890123456'), isNull); // 16 chiffres
    });

    test('numéro local : le pays n’est jamais deviné', () {
      expect(url('07 12 34 56 78'), isNull);
      expect(WhatsAppQrData.isLocalNumber('07 12 34 56 78'), isTrue);
      expect(WhatsAppQrData.isLocalNumber('+225 07 12 34 56 78'), isFalse);
      expect(WhatsAppQrData.isLocalNumber('00225 07 12'), isFalse);
    });
  });

  group('validation', () {
    test('numéro obligatoire, valide et international', () {
      expect(
        QrContentState.validateWhatsAppPhone(''),
        'Veuillez saisir un numéro WhatsApp.',
      );
      expect(
        QrContentState.validateWhatsAppPhone('abc'),
        'Veuillez saisir un numéro WhatsApp valide.',
      );
      expect(
        QrContentState.validateWhatsAppPhone('07 12 34 56 78'),
        contains('indicatif'),
      );
      expect(QrContentState.validateWhatsAppPhone('+225 07 12 34 56 78'), null);
    });

    test('titre obligatoire, message facultatif et limité', () {
      expect(QrContentState.validateWhatsAppTitle(' '), isNotNull);
      expect(QrContentState.validateWhatsAppMessage(''), isNull);
      expect(
        QrContentState.validateWhatsAppMessage(
          'x' * (WhatsAppQrData.maxMessageLength + 1),
        ),
        isNotNull,
      );
    });
  });

  test('le titre par défaut n’entre pas dans le lien', () {
    const data = WhatsAppQrData(phone: '+225 07 12 34 56 78');

    expect(data.title, 'Contactez-moi sur WhatsApp');
    expect(data.url, 'https://wa.me/2250712345678');
    expect(data.displayPhone, '+2250712345678');
  });

  test('toJson puis fromJson restituent la saisie', () {
    const data = WhatsAppQrData(
      title: 'Mon WhatsApp',
      phone: '+225 07 12 34 56 78',
      message: message,
    );

    final json = data.toJson();
    final restored = WhatsAppQrData.fromJson(data.title, json);

    expect(json['mode'], 'whatsapp');
    expect(json['links'], [
      {'platform': 'whatsapp', 'url': 'https://wa.me/2250712345678'},
    ]);
    expect(restored.title, 'Mon WhatsApp');
    expect(restored.url, data.url);
    expect(restored.message, message);
  });
}
