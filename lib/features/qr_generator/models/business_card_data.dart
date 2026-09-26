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

  // Champs de l'API, en snake_case (voir `backend/app/cards.py`).
  Map<String, String> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'job_title': jobTitle.trim(),
    'company': company.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'website': website.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'country': country.trim(),
    'linkedin': linkedin.trim(),
    'instagram': instagram.trim(),
    'whatsapp': whatsapp.trim(),
  };

  factory BusinessCardData.fromJson(Map<String, Object?> json) {
    String field(String name) =>
        json[name] is String ? json[name] as String : '';
    return BusinessCardData(
      firstName: field('first_name'),
      lastName: field('last_name'),
      jobTitle: field('job_title'),
      company: field('company'),
      phone: field('phone'),
      email: field('email'),
      website: field('website'),
      address: field('address'),
      city: field('city'),
      country: field('country'),
      linkedin: field('linkedin'),
      instagram: field('instagram'),
      whatsapp: field('whatsapp'),
    );
  }
}

// Carte publiée dans l'annuaire partagé, visible par tous les utilisateurs.
class SavedBusinessCard {
  const SavedBusinessCard({required this.id, required this.data});

  final String id;
  final BusinessCardData data;
}
