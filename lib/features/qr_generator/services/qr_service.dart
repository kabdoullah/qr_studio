import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../models/business_card_data.dart';
import '../models/qr_style.dart';
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
      ..._uriLine('URL', _normalizeUrl(data.website)),
      if ([data.address, data.city, data.country].any(_isFilled))
        'ADR;TYPE=WORK:;;${_escape(data.address.trim())};'
            '${_escape(data.city.trim())};;;${_escape(data.country.trim())}',
      ..._uriLine(
        'URL;TYPE=LinkedIn',
        _profileUrl(data.linkedin, 'https://www.linkedin.com/in/'),
      ),
      ..._uriLine(
        'URL;TYPE=Instagram',
        _profileUrl(data.instagram, 'https://www.instagram.com/'),
      ),
      ..._uriLine('URL;TYPE=WhatsApp', _whatsappUrl(data.whatsapp)),
      'END:VCARD',
    ];
    // La RFC 2426 impose des fins de ligne CRLF.
    return lines.join('\r\n');
  }

  // Le QR Code d'un fichier partagé (CV, image de carte de visite) contient
  // uniquement son URL publique.
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

  static bool _hasScheme(String value) =>
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(value);

  // Ajoute « https:// » à une adresse saisie sans protocole.
  static String? _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return _hasScheme(trimmed) ? trimmed : 'https://$trimmed';
  }

  // Accepte un lien (avec ou sans protocole) ou un simple nom d'utilisateur.
  // Un nom d'utilisateur peut contenir des points (« jean.dupont ») : seul
  // un « / » indique qu'il s'agit d'un lien.
  static String? _profileUrl(String value, String baseUrl) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_hasScheme(trimmed) || trimmed.contains('/')) {
      return _normalizeUrl(trimmed);
    }
    final handle = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return '$baseUrl${Uri.encodeComponent(handle)}';
  }

  // Transforme un numéro WhatsApp en lien wa.me (chiffres uniquement).
  static String? _whatsappUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_hasScheme(trimmed)) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : 'https://wa.me/$digits';
  }
}

final qrServiceProvider = Provider<QrService>((ref) => const QrService());
