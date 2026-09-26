// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_share_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrShareService)
final qrShareServiceProvider = QrShareServiceProvider._();

final class QrShareServiceProvider
    extends $FunctionalProvider<QrShareService, QrShareService, QrShareService>
    with $Provider<QrShareService> {
  QrShareServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrShareServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrShareServiceHash();

  @$internal
  @override
  $ProviderElement<QrShareService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QrShareService create(Ref ref) {
    return qrShareService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrShareService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrShareService>(value),
    );
  }
}

String _$qrShareServiceHash() => r'77d9733fb2c7e028855507bb94df7ed9c15a9807';
