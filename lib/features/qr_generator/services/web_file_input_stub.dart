import '../models/shared_file.dart';

// Hors du web, la sélection passe par file_picker.
Future<SharedFile?> pickWebFile({required String accept}) =>
    throw UnsupportedError('Sélection web indisponible sur cette plateforme.');
