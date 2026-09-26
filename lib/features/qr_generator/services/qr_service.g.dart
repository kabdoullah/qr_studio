// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrService)
final qrServiceProvider = QrServiceProvider._();

final class QrServiceProvider
    extends $FunctionalProvider<QrService, QrService, QrService>
    with $Provider<QrService> {
  QrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrServiceHash();

  @$internal
  @override
  $ProviderElement<QrService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QrService create(Ref ref) {
    return qrService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrService>(value),
    );
  }
}

String _$qrServiceHash() => r'fb272b0c9e30b0a1ae8f8cf8022754ef4fe36ef3';
