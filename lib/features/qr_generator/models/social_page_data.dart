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
class SocialPageData {
  const SocialPageData({this.title = '', this.bio = '', this.links = const []});

  // Limites identiques à celles du serveur.
  static const int maxTitleLength = 80;
  static const int maxBioLength = 300;
  static const int maxLinks = 10;

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
}
