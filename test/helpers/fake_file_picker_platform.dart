import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart' show XFile;

// Plateforme `file_picker` simulée : remplace le sélecteur natif.
class FakeFilePickerPlatform extends FilePickerPlatform {
  PlatformFile? pickedFile;
  Uri? savedUri = Uri.parse('content://documents/qr.png');

  FileType? lastType;
  List<String>? lastExtensions;
  DarwinOptions? lastDarwinOptions;
  ({String fileName, String mimeType, Uint8List bytes})? lastSave;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastType = type;
    lastExtensions = allowedExtensions;
    lastDarwinOptions = darwinOptions;
    return pickedFile;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastSave = (fileName: fileName, mimeType: mimeType, bytes: bytes);
    return savedUri;
  }
}

// Fichier choisi simulé. `knownSize` : taille fournie par le sélecteur
// (`null` si elle doit être lue) ; `readSize` : taille lue sur le disque.
final class FakePlatformFile extends PlatformFile {
  FakePlatformFile({
    required this.name,
    this.knownSize,
    this.readSize,
    String path = '/cache/cv.pdf',
  }) : uri = Uri.file(path);

  @override
  final String name;
  @override
  final Uri uri;
  final int? knownSize;
  final int? readSize;
  int readCount = 0;

  @override
  int? lengthSync() => knownSize;

  @override
  Future<int?> length() async {
    readCount++;
    return readSize;
  }

  @override
  XFile get xFile => XFile(uri.toFilePath(), name: name);

  // Le service ne doit jamais charger le PDF en mémoire.
  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Le PDF ne doit pas être lu en mémoire.');

  @override
  Stream<Uint8List> readAsByteStream() =>
      throw StateError('Le PDF ne doit pas être lu en mémoire.');
}
