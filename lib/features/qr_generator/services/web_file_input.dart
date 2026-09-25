import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/shared_file.dart';

// Sélection de fichier sur le web par un <input type="file">. Remplace
// file_picker_web, qui retire le champ de la page juste après l'avoir
// ouvert : Safari iOS ne rendait alors jamais le fichier choisi. Le champ
// reste ici dans la page jusqu'au choix ou à l'annulation.
//
// `click()` doit partir avant tout `await` : le navigateur n'ouvre le
// sélecteur que pendant le geste de l'utilisateur.
Future<SharedFile?> pickWebFile({required String accept}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  final picked = Completer<web.File?>();
  input
    ..addEventListener(
      'change',
      ((web.Event _) {
        if (!picked.isCompleted) picked.complete(input.files?.item(0));
      }).toJS,
    )
    // Événement `cancel` : Safari 16.4 et plus, Chrome 113 et plus.
    ..addEventListener(
      'cancel',
      ((web.Event _) {
        if (!picked.isCompleted) picked.complete(null);
      }).toJS,
    );
  web.document.body!.append(input);
  input.click();

  try {
    final file = await picked.future;
    if (file == null) return null;
    // Contenu lu tout de suite, sauf si le fichier dépasse la limite : il
    // sera refusé à la validation.
    final bytes = file.size <= SharedFileKind.maxSizeBytes
        ? (await file.arrayBuffer().toDart).toDart.asUint8List()
        : null;
    return SharedFile(name: file.name, size: file.size, bytes: bytes);
  } finally {
    input.remove();
  }
}
