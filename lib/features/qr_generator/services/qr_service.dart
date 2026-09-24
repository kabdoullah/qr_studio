import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../models/business_card_data.dart';
import '../models/qr_style.dart';
import '../models/social_network.dart';
import '../models/text_qr_data.dart';

// Construit le contenu textuel (payload) encodé dans les QR Codes.
class QrService {
  const QrService();

  // Génère le payload vCard 3.0 à partir des informations de la carte de
  // visite. Les champs vides sont omis.
  String generateBusinessCardPayload(BusinessCardData data) {
    final firstName = data.firstName.trim();
    final lastName = data.lastName.trim();
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:${_escape(lastName)};${_escape(firstName)};;;',
      'FN:${_escape(fullName)}',
      ..._textLine('ORG', data.company),
      ..._textLine('TITLE', data.jobTitle),
      ..._textLine('TEL;TYPE=CELL', data.phone),
      ..._textLine('EMAIL;TYPE=INTERNET', data.email),
      ..._uriLine('URL', SocialNetwork.website.normalize(data.website)),
      if ([data.address, data.city, data.country].any(_isFilled))
        'ADR;TYPE=WORK:;;${_escape(data.address.trim())};'
            '${_escape(data.city.trim())};;;${_escape(data.country.trim())}',
      ..._uriLine(
        'URL;TYPE=LinkedIn',
        SocialNetwork.linkedin.normalize(data.linkedin),
      ),
      ..._uriLine(
        'URL;TYPE=Instagram',
        SocialNetwork.instagram.normalize(data.instagram),
      ),
      ..._uriLine(
        'URL;TYPE=WhatsApp',
        SocialNetwork.whatsapp.normalize(data.whatsapp),
      ),
      'END:VCARD',
    ];
    // La RFC 2426 impose des fins de ligne CRLF.
    return lines.join('\r\n');
  }

  // Le QR Code d'un contenu en ligne (CV, image de carte de visite, page de
  // réseaux sociaux) contient uniquement son URL publique.
  String generateLinkPayload(String remoteUrl) => remoteUrl.trim();

  // Le texte est encodé tel quel, sans modification.
  String generateTextPayload(TextQrData data) => data.text;

  // Capacité maximale en octets (mode binaire, version 40) par niveau de
  // correction d'erreur. Les modes numérique et alphanumérique ont une
  // capacité supérieure : cette borne est donc prudente.
  static const Map<int, int> _maxBytes = {
    QrErrorCorrectLevel.L: 2953,
    QrErrorCorrectLevel.M: 2331,
    QrErrorCorrectLevel.Q: 1663,
    QrErrorCorrectLevel.H: 1273,
  };

  // Indique si le payload tient dans un QR Code au niveau de correction du
  // style. Les caractères accentués ou les emojis occupent plusieurs octets.
  static bool fitsInQrCode(String payload, {QrStyle style = const QrStyle()}) {
    return utf8.encode(payload).length <= _maxBytes[style.errorCorrectLevel]!;
  }

  static bool _isFilled(String value) => value.trim().isNotEmpty;

  static List<String> _textLine(String property, String value) =>
      _isFilled(value) ? ['$property:${_escape(value.trim())}'] : const [];

  static List<String> _uriLine(String property, String? uri) =>
      uri == null ? const [] : ['$property:$uri'];

  // Échappe les caractères réservés des valeurs texte vCard (RFC 2426 §4).
  static String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');
}

final qrServiceProvider = Provider<QrService>((ref) => const QrService());
