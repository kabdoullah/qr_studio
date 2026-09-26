import 'dart:convert';

import 'package:dio/dio.dart';

// Requête reçue par `FakeHttpAdapter`, corps compris (multipart encodé).
class RecordedRequest {
  const RecordedRequest(this.options, this.body);

  final RequestOptions options;
  final String body;

  String get method => options.method;
  Uri get uri => options.uri;
  String? header(String name) => options.headers[name]?.toString();
}

// Transport HTTP simulé pour Dio : `handler` répond à chaque requête (ou
// lève une `DioException`/erreur réseau).
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RecordedRequest request) handler;
  final List<RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? const <int>[]
        : (await requestStream.toList()).expand((chunk) => chunk).toList();
    final request = RecordedRequest(
      options,
      utf8.decode(bytes, allowMalformed: true),
    );
    requests.add(request);
    return handler(request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object? body) => ResponseBody.fromBytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
