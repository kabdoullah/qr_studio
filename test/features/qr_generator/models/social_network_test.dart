import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/features/qr_generator/models/social_network.dart';

void main() {
  group('toUrl', () {
    test('transforme un nom d’utilisateur en lien de profil', () {
      expect(
        SocialNetwork.instagram.toUrl(' @jean.dupont '),
        'https://www.instagram.com/jean.dupont',
      );
      expect(SocialNetwork.tiktok.toUrl('awa'), 'https://www.tiktok.com/@awa');
      expect(SocialNetwork.telegram.toUrl('@awa'), 'https://t.me/awa');
      expect(SocialNetwork.x.toUrl('awa_ci'), 'https://x.com/awa_ci');
    });

    test('accepte un lien complet ou sans protocole', () {
      expect(
        SocialNetwork.linkedin.toUrl('linkedin.com/in/awa'),
        'https://linkedin.com/in/awa',
      );
      expect(
        SocialNetwork.youtube.toUrl('https://youtu.be/abc'),
        'https://youtu.be/abc',
      );
      expect(
        SocialNetwork.x.toUrl('https://twitter.com/awa'),
        'https://twitter.com/awa',
      );
    });

    test('passe les liens http en https', () {
      expect(
        SocialNetwork.facebook.toUrl('http://www.facebook.com/awa'),
        'https://www.facebook.com/awa',
      );
    });

    test('transforme un numéro WhatsApp en lien wa.me', () {
      expect(
        SocialNetwork.whatsapp.toUrl('+225 07 00-00-00'),
        'https://wa.me/22507000000',
      );
      expect(SocialNetwork.whatsapp.toUrl('pas de chiffres'), isNull);
    });

    test('accepte tout domaine pour un site web', () {
      expect(SocialNetwork.website.toUrl('awa.design'), 'https://awa.design');
      expect(
        SocialNetwork.website.toUrl('https://sous.domaine.org/page?a=1'),
        'https://sous.domaine.org/page?a=1',
      );
    });

    test('refuse un domaine qui ne correspond pas au réseau', () {
      expect(SocialNetwork.instagram.toUrl('https://evil.com/awa'), isNull);
      expect(
        SocialNetwork.instagram.toUrl('https://instagram.com.evil.com/a'),
        isNull,
      );
      expect(
        SocialNetwork.instagram.toUrl('https://instagram.com@evil.com/a'),
        isNull,
      );
    });

    test('refuse les saisies invalides', () {
      expect(SocialNetwork.instagram.toUrl('   '), isNull);
      expect(SocialNetwork.instagram.toUrl('@'), isNull);
      expect(SocialNetwork.instagram.toUrl('jean dupont'), isNull);
      expect(SocialNetwork.website.toUrl('javascript://alert(1)'), isNull);
      expect(SocialNetwork.website.toUrl('ftp://awa.design'), isNull);
      expect(SocialNetwork.website.toUrl('localhost'), isNull);
      expect(SocialNetwork.website.toUrl('awa.design/${'a' * 300}'), isNull);
    });
  });

  test('normalize conserve le comportement de la vCard', () {
    expect(SocialNetwork.website.normalize('ftp://a.b'), 'ftp://a.b');
    expect(SocialNetwork.linkedin.normalize(''), isNull);
  });
}
