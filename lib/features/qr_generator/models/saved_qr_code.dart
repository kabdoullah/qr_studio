import 'qr_type.dart';

// QR Code enregistré sur le compte (`/api/v1/qr-codes`).
class SavedQrCode {
  const SavedQrCode({
    required this.id,
    required this.type,
    required this.title,
    required this.publicUrl,
    required this.content,
    this.updatedAt,
  });

  final String id;
  final QrType type;
  final String title;

  // Adresse `/q/{slug}` : ne change jamais, même après modification.
  final String publicUrl;

  // Contenu tel que renvoyé par le serveur (propre à chaque type).
  final Map<String, Object?> content;
  final DateTime? updatedAt;

  // `null` si la réponse du serveur est incomplète ou d'un type inconnu.
  static SavedQrCode? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'type': final String typeName,
      'title': final String title,
      'public_url': final String publicUrl,
      'content': final Map<String, Object?> content,
    }) {
      final type = QrType.fromApiName(typeName);
      if (type == null) return null;
      return SavedQrCode(
        id: id,
        type: type,
        title: title,
        publicUrl: publicUrl,
        content: content,
        updatedAt: DateTime.tryParse('${json['updated_at']}'),
      );
    }
    return null;
  }

  // Même forme que la réponse du serveur (relue par `fromJson`).
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.apiName,
    'title': title,
    'public_url': publicUrl,
    'content': content,
    if (updatedAt case final date?) 'updated_at': date.toIso8601String(),
  };

  // Contenu d'un objet imbriqué (ex. `details` d'une carte de visite).
  Map<String, Object?> section(String name) =>
      content[name] is Map<String, Object?>
      ? content[name] as Map<String, Object?>
      : const {};
}
