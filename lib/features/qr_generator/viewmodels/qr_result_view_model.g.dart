// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_result_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QrResultViewModel)
final qrResultViewModelProvider = QrResultViewModelProvider._();

final class QrResultViewModelProvider
    extends $NotifierProvider<QrResultViewModel, QrResultAction?> {
  QrResultViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrResultViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrResultViewModelHash();

  @$internal
  @override
  QrResultViewModel create() => QrResultViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrResultAction? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrResultAction?>(value),
    );
  }
}

String _$qrResultViewModelHash() => r'cc6961e43615399f20be8e814f4935f6ab04f46d';

abstract class _$QrResultViewModel extends $Notifier<QrResultAction?> {
  QrResultAction? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<QrResultAction?, QrResultAction?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrResultAction?, QrResultAction?>,
              QrResultAction?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
