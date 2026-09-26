// Texte libre encodé dans le QR Code.
class TextQrData {
  const TextQrData({this.text = ''});

  // Nombre maximal de caractères saisissables.
  static const int maxLength = 1000;

  final String text;

  Map<String, Object?> toJson() => {'text': text};

  factory TextQrData.fromJson(Map<String, Object?> json) =>
      TextQrData(text: json['text'] is String ? json['text'] as String : '');
}
