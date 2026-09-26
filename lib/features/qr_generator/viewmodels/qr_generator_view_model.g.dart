// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_generator_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QrGeneratorViewModel)
final qrGeneratorViewModelProvider = QrGeneratorViewModelProvider._();

final class QrGeneratorViewModelProvider
    extends $NotifierProvider<QrGeneratorViewModel, QrType?> {
  QrGeneratorViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrGeneratorViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrGeneratorViewModelHash();

  @$internal
  @override
  QrGeneratorViewModel create() => QrGeneratorViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrType? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrType?>(value),
    );
  }
}

String _$qrGeneratorViewModelHash() =>
    r'ac800693d12763755b637ac2a57e33a8fa7d078a';

abstract class _$QrGeneratorViewModel extends $Notifier<QrType?> {
  QrType? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<QrType?, QrType?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrType?, QrType?>,
              QrType?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
