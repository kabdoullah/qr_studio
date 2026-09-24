// Texte libre encodé dans le QR Code.
class TextQrData {
  const TextQrData({this.text = ''});

  // Nombre maximal de caractères saisissables.
  static const int maxLength = 1000;

  final String text;
}
