// Discussion WhatsApp : le QR Code contient directement le lien wa.me
// (conversation avec le numéro, message éventuellement prérempli), sans
// page intermédiaire ni serveur.
class WhatsAppQrData {
  const WhatsAppQrData({
    this.title = defaultTitle,
    this.phone = '',
    this.message = '',
  });

  static const String defaultTitle = 'Contactez-moi sur WhatsApp';

  // Limites identiques à celles du serveur.
  static const int maxTitleLength = 100;
  static const int maxMessageLength = 300;

  // Numéro international (E.164) : indicatif du pays compris, 15 chiffres
  // au plus ; les plus courts (petits pays) en comptent 7.
  static const int minDigits = 7;
  static const int maxDigits = 15;

  // Titre affiché dans « Mes QR Codes » ; il n'entre pas dans le lien.
  final String title;
  final String phone;
  final String message;

  WhatsAppQrData copyWith({String? title, String? phone, String? message}) =>
      WhatsAppQrData(
        title: title ?? this.title,
        phone: phone ?? this.phone,
        message: message ?? this.message,
      );

  // Chiffres du numéro international (« +225 07 12 34 56 78 » ou
  // « 00225… » donnent « 2250712345678 »), ou `null` si la saisie n'est pas
  // un numéro. Un numéro local (« 07 12… ») est refusé : le pays n'est
  // jamais deviné.
  static String? normalizePhone(String input) {
    final value = input.trim();
    // Chiffres et séparateurs visuels uniquement, « + » en tête.
    if (!RegExp(r'^\+?[\d\s().\-/]+$').hasMatch(value)) return null;
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (!value.startsWith('+') && digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) return null;
    if (digits.length < minDigits || digits.length > maxDigits) return null;
    return digits;
  }

  // Saisie locale (« 07 12… ») : il manque l'indicatif du pays.
  static bool isLocalNumber(String input) {
    final value = input.trim();
    return !value.startsWith('+') &&
        RegExp(r'^0[1-9]').hasMatch(value.replaceAll(RegExp(r'\D'), ''));
  }

  // Lien ouvrant la conversation : `https://wa.me/<chiffres>`, suivi de
  // `?text=<message encodé>` si un message est renseigné. `null` si le
  // numéro est invalide.
  static String? buildUrl({required String phoneNumber, String? message}) {
    final digits = normalizePhone(phoneNumber);
    if (digits == null) return null;
    final text = message?.trim() ?? '';
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: digits,
      // `encodeComponent` : espaces en %20, que WhatsApp restitue tels quels.
      query: text.isEmpty ? null : 'text=${Uri.encodeComponent(text)}',
    ).toString();
  }

  String? get url => buildUrl(phoneNumber: phone, message: message);

  // Numéro affiché (« +2250712345678 »), ou la saisie si elle est invalide.
  String get displayPhone {
    final digits = normalizePhone(phone);
    return digits == null ? phone.trim() : '+$digits';
  }

  // Contenu envoyé au serveur (type « réseaux sociaux », mode `whatsapp`) :
  // un seul lien wa.me, le message à part.
  Map<String, Object?> toJson() => {
    'mode': 'whatsapp',
    'description': '',
    'links': [
      {'platform': 'whatsapp', 'url': buildUrl(phoneNumber: phone)},
    ],
    'message': message.trim(),
  };

  factory WhatsAppQrData.fromJson(String title, Map<String, Object?> json) {
    var phone = '';
    if (json['links'] case [{'url': final String url}, ...]) {
      final digits = Uri.tryParse(url)?.pathSegments.firstOrNull;
      if (digits != null && normalizePhone(digits) != null) phone = '+$digits';
    }
    return WhatsAppQrData(
      title: title,
      phone: phone,
      message: json['message'] is String ? json['message'] as String : '',
    );
  }
}
