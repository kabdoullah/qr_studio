// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_history_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrHistoryCache)
final qrHistoryCacheProvider = QrHistoryCacheProvider._();

final class QrHistoryCacheProvider
    extends $FunctionalProvider<QrHistoryCache, QrHistoryCache, QrHistoryCache>
    with $Provider<QrHistoryCache> {
  QrHistoryCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrHistoryCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrHistoryCacheHash();

  @$internal
  @override
  $ProviderElement<QrHistoryCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QrHistoryCache create(Ref ref) {
    return qrHistoryCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrHistoryCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrHistoryCache>(value),
    );
  }
}

String _$qrHistoryCacheHash() => r'203a2ded64d557e2cad817de010fb7344e2f1ffc';
