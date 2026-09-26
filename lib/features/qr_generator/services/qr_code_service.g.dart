// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_code_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrCodeService)
final qrCodeServiceProvider = QrCodeServiceProvider._();

final class QrCodeServiceProvider
    extends $FunctionalProvider<QrCodeService?, QrCodeService?, QrCodeService?>
    with $Provider<QrCodeService?> {
  QrCodeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrCodeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrCodeServiceHash();

  @$internal
  @override
  $ProviderElement<QrCodeService?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QrCodeService? create(Ref ref) {
    return qrCodeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrCodeService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrCodeService?>(value),
    );
  }
}

String _$qrCodeServiceHash() => r'50a609d341f5e9a90b766037a2d5768420ff9cf9';
