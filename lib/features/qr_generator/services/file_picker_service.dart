import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_file.dart';
import 'web_file_input_stub.dart'
    if (dart.library.js_interop) 'web_file_input.dart';

// Sélection de fichiers sur l'appareil via le sélecteur natif. Renvoie
// `null` si l'utilisateur annule. Le contenu n'est pas chargé en mémoire,
// sauf sur le web où il n'existe pas de chemin local.
class FilePickerService {
  const FilePickerService();

  // Sélecteur de documents limité aux PDF.
  Future<SharedFile?> pickPdf() => kIsWeb
      ? pickWebFile(accept: '.pdf,application/pdf')
      : _pick(
          FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: const ['pdf'],
          ),
        );

  // Galerie photos. Sur iOS, les photos HEIC sont converties dans un format
  // compatible (JPEG) lisible par tous les navigateurs ; Safari fait de même
  // pour `image/*`.
  Future<SharedFile?> pickImage() => kIsWeb
      ? pickWebFile(accept: 'image/*')
      : _pick(
          FilePicker.pickFile(
            type: FileType.image,
            darwinOptions: const DarwinOptions(
              assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
            ),
          ),
        );

  Future<SharedFile?> _pick(Future<PlatformFile?> picking) async {
    final file = await picking;
    if (file == null) return null;

    final size = file.lengthSync() ?? await file.length();
    if (size == null) {
      throw StateError('Taille du fichier « ${file.name} » inconnue.');
    }
    return SharedFile(name: file.name, size: size, localPath: file.path);
  }
}

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const FilePickerService(),
);
