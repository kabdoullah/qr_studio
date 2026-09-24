// Coordonnées saisies pour la carte de visite (encodées en vCard).
class BusinessCardData {
  const BusinessCardData({
    this.firstName = '',
    this.lastName = '',
    this.jobTitle = '',
    this.company = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.city = '',
    this.country = '',
    this.linkedin = '',
    this.instagram = '',
    this.whatsapp = '',
  });

  final String firstName;
  final String lastName;
  final String jobTitle;
  final String company;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String city;
  final String country;
  final String linkedin;
  final String instagram;
  final String whatsapp;

  BusinessCardData copyWith({
    String? firstName,
    String? lastName,
    String? jobTitle,
    String? company,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? country,
    String? linkedin,
    String? instagram,
    String? whatsapp,
  }) {
    return BusinessCardData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      linkedin: linkedin ?? this.linkedin,
      instagram: instagram ?? this.instagram,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }
}

// Carte publiée dans l'annuaire partagé, visible par tous les utilisateurs.
class SavedBusinessCard {
  const SavedBusinessCard({required this.id, required this.data});

  final String id;
  final BusinessCardData data;
}
