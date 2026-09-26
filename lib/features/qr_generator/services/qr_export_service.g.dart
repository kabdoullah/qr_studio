// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_export_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrExportService)
final qrExportServiceProvider = QrExportServiceProvider._();

final class QrExportServiceProvider
    extends
        $FunctionalProvider<QrExportService, QrExportService, QrExportService>
    with $Provider<QrExportService> {
  QrExportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrExportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrExportServiceHash();

  @$internal
  @override
  $ProviderElement<QrExportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QrExportService create(Ref ref) {
    return qrExportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrExportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrExportService>(value),
    );
  }
}

String _$qrExportServiceHash() => r'dbb2a6653bc1ebce06b2cf2e1a1e117c19df6bf4';
