// Site web : le QR Code mène à l'adresse publique QR Studio, qui ouvre
// ce site (modifiable sans réimprimer le QR Code).
class WebsiteQrData {
  const WebsiteQrData({this.title = '', this.url = ''});

  // Limites identiques à celles du serveur.
  static const int maxTitleLength = 100;
  static const int maxUrlLength = 500;

  final String title;
  final String url;

  WebsiteQrData copyWith({String? title, String? url}) =>
      WebsiteQrData(title: title ?? this.title, url: url ?? this.url);

  // « exemple.com » devient « https://exemple.com ».
  static String normalizeUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return value;
    final hasScheme = RegExp(
      r'^[a-z][a-z0-9+.-]*:',
      caseSensitive: false,
    ).hasMatch(value);
    return hasScheme ? value : 'https://$value';
  }

  Map<String, Object?> toJson() => {'url': normalizeUrl(url)};

  factory WebsiteQrData.fromJson(String title, Map<String, Object?> json) =>
      WebsiteQrData(
        title: title,
        url: json['url'] is String ? json['url'] as String : '',
      );
}
