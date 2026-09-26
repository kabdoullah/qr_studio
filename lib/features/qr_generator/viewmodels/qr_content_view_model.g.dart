// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_content_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QrContentViewModel)
final qrContentViewModelProvider = QrContentViewModelProvider._();

final class QrContentViewModelProvider
    extends $NotifierProvider<QrContentViewModel, QrContentState> {
  QrContentViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrContentViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrContentViewModelHash();

  @$internal
  @override
  QrContentViewModel create() => QrContentViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrContentState>(value),
    );
  }
}

String _$qrContentViewModelHash() =>
    r'd96d461f0d44fe801baf681a262127142c14bce3';

abstract class _$QrContentViewModel extends $Notifier<QrContentState> {
  QrContentState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<QrContentState, QrContentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrContentState, QrContentState>,
              QrContentState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(livePreview)
final livePreviewProvider = LivePreviewProvider._();

final class LivePreviewProvider
    extends $FunctionalProvider<LivePreview?, LivePreview?, LivePreview?>
    with $Provider<LivePreview?> {
  LivePreviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'livePreviewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$livePreviewHash();

  @$internal
  @override
  $ProviderElement<LivePreview?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LivePreview? create(Ref ref) {
    return livePreview(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LivePreview? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LivePreview?>(value),
    );
  }
}

String _$livePreviewHash() => r'2763f5633df42f1152d02b4fe4ac86d86159b645';
