import 'package:flutter/material.dart';

// Réseaux proposés sur une page de réseaux sociaux. `name` est la clé
// envoyée au serveur, qui n'accepte pour chaque réseau que ses domaines.
enum SocialNetwork {
  instagram(
    label: 'Instagram',
    icon: Icons.photo_camera_outlined,
    hint: '@votre_compte',
    profileBase: 'https://www.instagram.com/',
    domains: ['instagram.com'],
  ),
  tiktok(
    label: 'TikTok',
    icon: Icons.tiktok,
    hint: '@votre_compte',
    profileBase: 'https://www.tiktok.com/@',
    domains: ['tiktok.com'],
  ),
  facebook(
    label: 'Facebook',
    icon: Icons.facebook,
    hint: 'Nom de la page ou lien',
    profileBase: 'https://www.facebook.com/',
    domains: ['facebook.com', 'fb.com'],
  ),
  x(
    label: 'X (Twitter)',
    icon: Icons.alternate_email,
    hint: '@votre_compte',
    profileBase: 'https://x.com/',
    domains: ['x.com', 'twitter.com'],
  ),
  linkedin(
    label: 'LinkedIn',
    icon: Icons.work_outline,
    hint: 'Identifiant ou lien du profil',
    profileBase: 'https://www.linkedin.com/in/',
    domains: ['linkedin.com'],
  ),
  youtube(
    label: 'YouTube',
    icon: Icons.smart_display_outlined,
    hint: '@votre_chaine',
    profileBase: 'https://www.youtube.com/@',
    domains: ['youtube.com', 'youtu.be'],
  ),
  snapchat(
    label: 'Snapchat',
    icon: Icons.snapchat,
    hint: 'Nom d’utilisateur',
    profileBase: 'https://www.snapchat.com/add/',
    domains: ['snapchat.com'],
  ),
  whatsapp(
    label: 'WhatsApp',
    icon: Icons.chat_outlined,
    hint: 'Numéro avec indicatif (+225…)',
    domains: ['wa.me'],
  ),
  telegram(
    label: 'Telegram',
    icon: Icons.telegram,
    hint: '@votre_compte',
    profileBase: 'https://t.me/',
    domains: ['t.me'],
  ),
  website(
    label: 'Site web',
    icon: Icons.language,
    hint: 'exemple.com',
    domains: null,
  );

  const SocialNetwork({
    required this.label,
    required this.icon,
    required this.hint,
    required this.domains,
    this.profileBase,
  });

  final String label;
  final IconData icon;

  // Exemple de saisie affiché dans le champ.
  final String hint;

  // Préfixe ajouté à un simple nom d'utilisateur, ou `null` si le réseau
  // n'en a pas (numéro WhatsApp, site web).
  final String? profileBase;

  // Domaines acceptés (sous-domaines compris) ; `null` : tout domaine.
  final List<String>? domains;

  // Longueur maximale d'une adresse acceptée par le serveur.
  static const int maxUrlLength = 300;

  String get invalidMessage => switch (this) {
    whatsapp => 'Numéro WhatsApp invalide.',
    website => 'Adresse du site invalide.',
    _ => 'Lien $label invalide.',
  };

  // Transforme la saisie en adresse, sans la vérifier : un nom
  // d'utilisateur (« @jean.dupont ») devient un lien de profil, un numéro
  // WhatsApp un lien wa.me, et « https:// » est ajouté s'il manque.
  // Renvoie `null` pour une saisie vide.
  String? normalize(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (_hasScheme(value)) return value;
    if (this == whatsapp) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? null : 'https://wa.me/$digits';
    }
    // Un nom d'utilisateur peut contenir des points (« jean.dupont ») :
    // seul un « / » indique qu'il s'agit d'un lien.
    final base = profileBase;
    if (base == null || value.contains('/')) return 'https://$value';
    final handle = value.startsWith('@') ? value.substring(1) : value;
    return '$base${Uri.encodeComponent(handle)}';
  }

  // Adresse normalisée et vérifiée selon les mêmes règles que le serveur
  // (https, domaine du réseau), ou `null` si la saisie est invalide.
  String? toUrl(String input) {
    // Seul un numéro WhatsApp peut contenir des espaces.
    if (this != whatsapp && RegExp(r'\s').hasMatch(input.trim())) return null;
    var url = normalize(input);
    if (url == null || RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(url)) {
      return null;
    }
    // Les réseaux sont tous servis en https.
    if (url.toLowerCase().startsWith('http://')) {
      url = 'https://${url.substring('http://'.length)}';
    }
    if (url.length > maxUrlLength) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (!host.contains('.')) return null;
    final allowed = domains;
    if (allowed != null &&
        !allowed.any((d) => host == d || host.endsWith('.$d'))) {
      return null;
    }
    // Un nom d'utilisateur réduit à « @ » ne mène nulle part.
    if (profileBase != null && url == profileBase) return null;
    return url;
  }

  static bool _hasScheme(String value) =>
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(value);
}
