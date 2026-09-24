import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/core/utils/file_size_formatter.dart';

void main() {
  test('formate les tailles de fichier', () {
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(245 * 1024), '245 KB');
    expect(formatFileSize(1887437), '1.8 MB');
    expect(formatFileSize(10 * 1024 * 1024), '10 MB');
  });
}
