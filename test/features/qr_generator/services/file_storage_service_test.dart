import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';

void main() {
  late Directory dir;
  late SharedFile cv;
  late List<http.Request> requests;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('qr_studio_upload_');
    final file = File('${dir.path}/CV.pdf')..writeAsStringSync('%PDF-1.7');
    cv = SharedFile(name: 'CV.pdf', size: 8, localPath: file.path);
    requests = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  HttpFileStorageService serviceReplying(
    int status,
    Object body, {
    String baseUrl = 'http://192.168.1.10:8000',
  }) {
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status);
    });
    return HttpFileStorageService(baseUrl, client: client);
  }

  test('envoie le CV et renvoie le lien public', () async {
    final service = serviceReplying(201, {
      'id': 'AbCdEfGhIjKlMnOp',
      'url': 'http://192.168.1.10:8000/cv/AbCdEfGhIjKlMnOp',
    });

    final url = await service.upload(cv, SharedFileKind.cv);

    expect(url, 'http://192.168.1.10:8000/cv/AbCdEfGhIjKlMnOp');
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.toString(), 'http://192.168.1.10:8000/api/v1/cvs');
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    expect(request.body, contains('name="file"; filename="CV.pdf"'));
    expect(request.body, contains('%PDF-1.7'));
  });

  test("envoie l'image de carte vers son propre point d'accès", () async {
    final service = serviceReplying(201, {
      'id': 'x',
      'url': 'https://qrstudio.app/card/x',
    });

    await service.upload(cv, SharedFileKind.businessCardImage);

    expect(requests.single.url.path, '/api/v1/cards');
  });

  test("conserve le chemin de l'adresse du serveur", () async {
    final service = serviceReplying(201, {
      'id': 'x',
      'url': 'https://example.com/qr/cv/x',
    }, baseUrl: 'https://example.com/qr');

    await service.upload(cv, SharedFileKind.cv);

    expect(requests.single.url.toString(), 'https://example.com/qr/api/v1/cvs');
  });

  test('un statut d’erreur lève une exception', () async {
    final service = serviceReplying(415, {
      'detail': 'Le fichier doit être un PDF.',
    });

    expect(
      service.upload(cv, SharedFileKind.cv),
      throwsA(isA<FileUploadException>()),
    );
  });

  test('une réponse sans lien valide lève une exception', () async {
    for (final body in [
      {'id': 'x'},
      {'url': 'javascript:alert(1)'},
      ['pas', 'un', 'objet'],
    ]) {
      expect(
        serviceReplying(201, body).upload(cv, SharedFileKind.cv),
        throwsA(isA<FileUploadException>()),
        reason: '$body',
      );
    }
  });

  test('sans fichier local, rien n’est envoyé', () async {
    final service = serviceReplying(201, {'url': 'https://x/cv/y'});

    await expectLater(
      service.upload(
        const SharedFile(name: 'CV.pdf', size: 8),
        SharedFileKind.cv,
      ),
      throwsA(isA<FileUploadException>()),
    );
    expect(requests, isEmpty);
  });

  test('sans adresse de serveur, le stockage reste indisponible', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(fileStorageServiceProvider),
      isA<BackendRequiredFileStorageService>(),
    );
  });
}
