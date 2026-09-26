import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/features/qr_generator/models/shared_file.dart';
import 'package:qr_studio/features/qr_generator/services/file_storage_service.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late Directory dir;
  late SharedFile cv;
  late List<RecordedRequest> requests;

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
    final adapter = FakeHttpAdapter((_) async => jsonResponse(status, body));
    requests = adapter.requests;
    return HttpFileStorageService(
      ApiClient(
        baseUrl,
        readTokens: () =>
            const AuthTokens(accessToken: 'jeton', refreshToken: 'r'),
        onTokensRefreshed: (_) {},
        onUnauthorized: () {},
        adapter: adapter,
      ),
    );
  }

  test('envoie le CV et renvoie le lien public', () async {
    final service = serviceReplying(201, {
      'id': 'AbCdEfGhIjKlMnOp',
      'url': 'http://192.168.1.10:8000/cv/AbCdEfGhIjKlMnOp',
    });

    final remote = await service.upload(cv, SharedFileKind.cv);

    expect(remote.id, 'AbCdEfGhIjKlMnOp');
    expect(remote.url, 'http://192.168.1.10:8000/cv/AbCdEfGhIjKlMnOp');
    final request = requests.single;
    expect(request.method, 'POST');
    // Le fichier est rattaché au compte connecté.
    expect(request.header('Authorization'), 'Bearer jeton');
    expect(request.uri.toString(), 'http://192.168.1.10:8000/api/v1/cvs');
    expect(request.header('content-type'), startsWith('multipart/form-data'));
    expect(request.body, contains('name="file"; filename="CV.pdf"'));
    expect(request.body, contains('%PDF-1.7'));
  });

  test("envoie l'image de carte vers son propre point d'accès", () async {
    final service = serviceReplying(201, {
      'id': 'x',
      'url': 'https://qrstudio.app/card/x',
    });

    await service.upload(cv, SharedFileKind.businessCardImage);

    expect(requests.single.uri.path, '/api/v1/cards');
  });

  test("conserve le chemin de l'adresse du serveur", () async {
    final service = serviceReplying(201, {
      'id': 'x',
      'url': 'https://example.com/qr/cv/x',
    }, baseUrl: 'https://example.com/qr');

    await service.upload(cv, SharedFileKind.cv);

    expect(requests.single.uri.toString(), 'https://example.com/qr/api/v1/cvs');
  });

  test('un refus du serveur lève une exception avec son message', () async {
    final service = serviceReplying(415, {
      'detail': 'Le fichier doit être un PDF.',
    });

    expect(
      service.upload(cv, SharedFileKind.cv),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Le fichier doit être un PDF.',
        ),
      ),
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
        throwsA(isA<ApiException>()),
        reason: '$body',
      );
    }
  });

  test('sur le web, envoie le contenu gardé en mémoire', () async {
    final service = serviceReplying(201, {'id': 'y', 'url': 'https://x/cv/y'});

    final remote = await service.upload(
      SharedFile(
        name: 'CV.pdf',
        size: 8,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
      ),
      SharedFileKind.cv,
    );

    expect(remote.url, 'https://x/cv/y');
    expect(requests.single.body, contains('name="file"; filename="CV.pdf"'));
    expect(requests.single.body, contains('%PDF-1.7'));
  });

  test('sans fichier local, rien n’est envoyé', () async {
    final service = serviceReplying(201, {'url': 'https://x/cv/y'});

    await expectLater(
      service.upload(
        const SharedFile(name: 'CV.pdf', size: 8),
        SharedFileKind.cv,
      ),
      throwsA(isA<ApiException>()),
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
