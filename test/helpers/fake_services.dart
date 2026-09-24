import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/models/qr_code_data.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';
import 'package:qr_studio/features/qr_generator/services/file_picker_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_export_service.dart';
import 'package:qr_studio/features/qr_generator/services/qr_share_service.dart';

// Sélecteur simulé : renvoie le résultat programmé, ou lève `error`.
class FakeFilePickerService implements FilePickerService {
  SharedFile? next;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<SharedFile?> pickPdf() => _pick();

  @override
  Future<SharedFile?> pickImage() => _pick();

  Future<SharedFile?> _pick() async {
    calls++;
    await gate?.future;
    if (error case final e?) throw e;
    return next;
  }
}

// Stockage simulé : renvoie `url`, ou lève `error`.
class FakeFileStorageService implements FileStorageService {
  FakeFileStorageService({this.url = 'https://qrstudio.app/cv/a82f91d3'});

  final String url;
  Object? error;
  Completer<void>? gate;
  int uploads = 0;
  final List<SharedFileKind> kinds = [];

  @override
  Future<String> upload(SharedFile file, SharedFileKind kind) async {
    uploads++;
    kinds.add(kind);
    await gate?.future;
    if (error case final e?) throw e;
    return url;
  }
}

const validCv = SharedFile(
  name: 'CV_Abdoullah_Coulibaly.pdf',
  size: 1887437,
  localPath: '/tmp/CV_Abdoullah_Coulibaly.pdf',
);

// Export simulé : renvoie des octets fictifs, ou lève `error`.
class FakeQrExportService implements QrExportService {
  Object? error;
  final List<QrCodeData> exported = [];

  @override
  Future<Uint8List> exportPng(
    QrCodeData data, {
    int size = QrExportService.defaultSize,
  }) async {
    if (error case final e?) throw e;
    exported.add(data);
    return Uint8List.fromList([1, 2, 3]);
  }
}

// Partage simulé : mémorise les appels.
class FakeQrShareService implements QrShareService {
  Object? error;
  bool saveAccepted = true;
  final List<({String fileName, String? text, Rect? origin})> shares = [];
  final List<String> saves = [];

  @override
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    if (error case final e?) throw e;
    shares.add((fileName: fileName, text: text, origin: origin));
  }

  @override
  Future<bool> savePng(Uint8List png, {required String fileName}) async {
    if (error case final e?) throw e;
    saves.add(fileName);
    return saveAccepted;
  }
}
