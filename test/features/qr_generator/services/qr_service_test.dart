import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/business_card_data.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/models/saved_qr_code.dart';
import 'package:qr_studio/features/qr_generator/models/text_qr_data.dart';
import 'package:qr_studio/features/qr_generator/models/wifi_qr_data.dart';
import 'package:qr_studio/features/qr_generator/services/qr_service.dart';

void main() {
  const service = QrService();

  List<String> lines(BusinessCardData data) =>
      service.generateBusinessCardPayload(data).split('\r\n');

  group('generateBusinessCardPayload', () {
    test('produit une vCard 3.0 complète', () {
      final result = lines(
        const BusinessCardData(
          firstName: 'Abdoullah',
          lastName: 'Coulibaly',
          jobTitle: 'Software Engineer',
          company: 'Company',
          phone: '+225 07 00 00 00',
          email: 'abdoullah@example.com',
          website: 'example.com',
          address: '12 rue des Jardins',
          city: 'Abidjan',
          country: "Côte d'Ivoire",
        ),
      );

      expect(result, [
        'BEGIN:VCARD',
        'VERSION:3.0',
        'N:Coulibaly;Abdoullah;;;',
        'FN:Abdoullah Coulibaly',
        'ORG:Company',
        'TITLE:Software Engineer',
        'TEL;TYPE=CELL:+225 07 00 00 00',
        'EMAIL;TYPE=INTERNET:abdoullah@example.com',
        'URL:https://example.com',
        "ADR;TYPE=WORK:;;12 rue des Jardins;Abidjan;;;Côte d'Ivoire",
        'END:VCARD',
      ]);
    });

    test('omet les champs vides et supprime les espaces superflus', () {
      final result = lines(
        const BusinessCardData(firstName: '  Awa ', lastName: 'Traoré'),
      );

      expect(result, [
        'BEGIN:VCARD',
        'VERSION:3.0',
        'N:Traoré;Awa;;;',
        'FN:Awa Traoré',
        'END:VCARD',
      ]);
    });

    test('échappe les caractères spéciaux', () {
      final result = lines(
        const BusinessCardData(
          firstName: 'Jean',
          lastName: 'Dupont; Martin',
          company: r'A, B & C\D',
          address: 'Bât. 2\nÉtage 3',
        ),
      );

      expect(result, contains(r'N:Dupont\; Martin;Jean;;;'));
      expect(result, contains(r'FN:Jean Dupont\; Martin'));
      expect(result, contains(r'ORG:A\, B & C\\D'));
      expect(result, contains(r'ADR;TYPE=WORK:;;Bât. 2\nÉtage 3;;;;'));
    });

    test('conserve un site web qui a déjà un protocole', () {
      final result = lines(
        const BusinessCardData(
          firstName: 'A',
          lastName: 'B',
          website: 'http://example.com/page',
        ),
      );

      expect(result, contains('URL:http://example.com/page'));
    });

    test('convertit les réseaux sociaux en liens', () {
      final result = lines(
        const BusinessCardData(
          firstName: 'A',
          lastName: 'B',
          linkedin: 'abdoullah-coulibaly',
          instagram: '@jean.dupont',
          whatsapp: '+225 07 00-00-00',
        ),
      );

      expect(
        result,
        containsAll([
          'URL;TYPE=LinkedIn:https://www.linkedin.com/in/abdoullah-coulibaly',
          'URL;TYPE=Instagram:https://www.instagram.com/jean.dupont',
          'URL;TYPE=WhatsApp:https://wa.me/22507000000',
        ]),
      );
    });

    test('accepte des liens de profil complets', () {
      final result = lines(
        const BusinessCardData(
          firstName: 'A',
          lastName: 'B',
          linkedin: 'linkedin.com/in/abdoullah',
          instagram: 'https://instagram.com/jean',
        ),
      );

      expect(
        result,
        containsAll([
          'URL;TYPE=LinkedIn:https://linkedin.com/in/abdoullah',
          'URL;TYPE=Instagram:https://instagram.com/jean',
        ]),
      );
    });
  });

  group('generateTextPayload', () {
    test('conserve le texte tel quel', () {
      const text = '  Bonjour !\nÀ bientôt ; 😊 \\ , ';

      expect(service.generateTextPayload(const TextQrData(text: text)), text);
    });
  });

  group('fitsInQrCode', () {
    test('accepte 1000 caractères accentués', () {
      expect(QrService.fitsInQrCode('é' * TextQrData.maxLength), isTrue);
    });

    test('refuse un contenu qui dépasse la capacité en octets', () {
      // Un emoji occupe 4 octets : 1000 emojis dépassent 2331 octets.
      expect(QrService.fitsInQrCode('😊' * TextQrData.maxLength), isFalse);
    });
  });

  group('generateLinkPayload', () {
    test("utilise l'URL publique du CV", () {
      expect(
        service.generateLinkPayload(' https://qrstudio.app/cv/a82f91d3 '),
        'https://qrstudio.app/cv/a82f91d3',
      );
    });
  });

  group('generateWifiPayload', () {
    test('réseau WPA2 au format standard', () {
      expect(
        service.generateWifiPayload(
          const WifiQrData(ssid: 'Office-Wifi', password: 'secret123'),
        ),
        'WIFI:T:WPA;S:Office-Wifi;P:secret123;;',
      );
    });

    test('WPA et WPA3 utilisent la valeur compatible WPA', () {
      for (final security in [WifiSecurity.wpa, WifiSecurity.wpa3]) {
        expect(
          service.generateWifiPayload(
            WifiQrData(
              ssid: 'MyWifi',
              password: 'MyPassword',
              security: security,
            ),
          ),
          'WIFI:T:WPA;S:MyWifi;P:MyPassword;;',
        );
      }
    });

    test('WEP', () {
      expect(
        service.generateWifiPayload(
          const WifiQrData(
            ssid: 'Ancien',
            password: 'abcde',
            security: WifiSecurity.wep,
          ),
        ),
        'WIFI:T:WEP;S:Ancien;P:abcde;;',
      );
    });

    test('réseau ouvert : aucun mot de passe', () {
      expect(
        service.generateWifiPayload(
          const WifiQrData(
            ssid: 'FreeWifi',
            password: 'oublié',
            security: WifiSecurity.none,
          ),
        ),
        'WIFI:T:nopass;S:FreeWifi;;',
      );
    });

    test('réseau masqué', () {
      expect(
        service.generateWifiPayload(
          const WifiQrData(ssid: 'Cache', password: '12345678', hidden: true),
        ),
        'WIFI:T:WPA;S:Cache;P:12345678;H:true;;',
      );
    });

    test('échappe \\ ; , : " dans le nom et le mot de passe', () {
      expect(
        service.generateWifiPayload(
          const WifiQrData(ssid: r'Café;"Wi,Fi":\', password: r'p;a,s:s"\w'),
        ),
        r'WIFI:T:WPA;S:Café\;\"Wi\,Fi\"\:\\;P:p\;a\,s\:s\"\\w;;',
      );
    });

    test('toString ne révèle jamais le mot de passe', () {
      const wifi = WifiQrData(ssid: 'Maison', password: 'secret-wifi');

      expect(wifi.toString(), isNot(contains('secret-wifi')));
    });
  });

  group('réseaux sociaux et site web', () {
    const publicUrl = 'https://qrstudio.app/q/x8K2pLm91abc';

    test("encodent l'adresse publique QR Studio", () {
      expect(service.generateSocialMediaPayload(publicUrl), publicUrl);
      expect(service.generateWebsitePayload(' $publicUrl '), publicUrl);
    });
  });

  group('generateSavedPayload', () {
    SavedQrCode saved(QrType type, Map<String, Object?> content) => SavedQrCode(
      id: 'id',
      type: type,
      title: 'Titre',
      publicUrl: 'https://qr.test/q/slug',
      content: content,
    );

    test('types statiques : même contenu qu’à la création', () {
      expect(
        service.generateSavedPayload(saved(QrType.text, {'text': 'Bonjour'})),
        'Bonjour',
      );
      expect(
        service.generateSavedPayload(
          saved(QrType.wifi, {
            'ssid': 'Maison',
            'security': 'WPA2',
            'password': '12345678',
            'hidden': false,
          }),
        ),
        'WIFI:T:WPA;S:Maison;P:12345678;;',
      );
      expect(
        service.generateSavedPayload(
          saved(QrType.businessCard, {
            'mode': 'details',
            'details': {'first_name': 'Awa', 'last_name': 'Traoré'},
          }),
        ),
        startsWith('BEGIN:VCARD'),
      );
    });

    test('types dynamiques et fichiers : adresse publique', () {
      for (final (type, content) in [
        (QrType.website, <String, Object?>{'url': 'https://example.com'}),
        (QrType.socialMedia, <String, Object?>{'links': []}),
        (QrType.cv, <String, Object?>{'file_id': 'f'}),
        (QrType.businessCard, <String, Object?>{'mode': 'image'}),
      ]) {
        expect(
          service.generateSavedPayload(saved(type, content)),
          'https://qr.test/q/slug',
        );
      }
    });
  });
}
