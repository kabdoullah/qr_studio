import 'social_network.dart';

// Un réseau de la page, tel que saisi (nom d'utilisateur, numéro ou lien).
// `id` distingue les lignes du formulaire quand l'une d'elles est retirée.
class SocialLink {
  const SocialLink({required this.id, required this.network, this.value = ''});

  final int id;
  final SocialNetwork network;
  final String value;

  SocialLink withValue(String value) =>
      SocialLink(id: id, network: network, value: value);
}

// Contenu de la page publique de réseaux sociaux. La saisie brute est
// conservée pour être réaffichée quand l'utilisateur revient modifier.
// Le titre de la page est celui du QR Code.
class SocialPageData {
  const SocialPageData({this.title = '', this.bio = '', this.links = const []});

  // Limites identiques à celles du serveur.
  static const int maxTitleLength = 100;
  static const int maxBioLength = 300;
  static const int maxLinks = 15;

  final String title;
  final String bio;
  final List<SocialLink> links;

  SocialPageData copyWith({
    String? title,
    String? bio,
    List<SocialLink>? links,
  }) {
    return SocialPageData(
      title: title ?? this.title,
      bio: bio ?? this.bio,
      links: links ?? this.links,
    );
  }

  // Contenu envoyé au serveur. Les liens doivent être valides (voir
  // `SocialNetwork.toUrl`).
  Map<String, Object?> toJson() => {
    'description': bio.trim(),
    'links': [
      for (final link in links)
        {'platform': link.network.name, 'url': link.network.toUrl(link.value)},
    ],
  };

  factory SocialPageData.fromJson(String title, Map<String, Object?> json) {
    final links = <SocialLink>[];
    for (final item in json['links'] is List ? json['links'] as List : []) {
      if (item case {'platform': final String name, 'url': final String url}) {
        final network = SocialNetwork.values.where((n) => n.name == name);
        if (network.isEmpty) continue;
        links.add(
          SocialLink(id: links.length + 1, network: network.first, value: url),
        );
      }
    }
    return SocialPageData(
      title: title,
      bio: json['description'] is String ? json['description'] as String : '',
      links: links,
    );
  }
}
