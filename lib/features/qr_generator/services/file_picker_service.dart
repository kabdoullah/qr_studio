import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_file.dart';
import 'picker_web_options_stub.dart'
    if (dart.library.js_interop) 'picker_web_options_web.dart';

// Sélection de fichiers sur l'appareil via le sélecteur natif. Renvoie
// `null` si l'utilisateur annule. Le contenu n'est pas chargé en mémoire,
// sauf sur le web où il n'existe pas de chemin local.
class FilePickerService {
  const FilePickerService();

  // Sélecteur de documents limité aux PDF.
  Future<SharedFile?> pickPdf() => _pick(
    FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      webOptions: pickerWebOptions,
    ),
  );

  // Galerie photos. Sur iOS, les photos HEIC sont converties dans un format
  // compatible (JPEG) lisible par tous les navigateurs.
  Future<SharedFile?> pickImage() => _pick(
    FilePicker.pickFile(
      type: FileType.image,
      webOptions: pickerWebOptions,
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
    // Sur le web, le contenu est lu tout de suite, sauf si le fichier
    // dépasse la limite : il sera refusé à la validation.
    final bytes = kIsWeb && size <= SharedFileKind.maxSizeBytes
        ? await file.readAsBytes()
        : null;
    return SharedFile(
      name: file.name,
      size: size,
      localPath: file.path,
      bytes: bytes,
    );
  }
}

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const FilePickerService(),
);
