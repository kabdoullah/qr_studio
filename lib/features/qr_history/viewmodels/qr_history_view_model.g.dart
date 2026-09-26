// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_history_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QrHistoryViewModel)
final qrHistoryViewModelProvider = QrHistoryViewModelProvider._();

final class QrHistoryViewModelProvider
    extends $NotifierProvider<QrHistoryViewModel, QrHistoryState> {
  QrHistoryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrHistoryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrHistoryViewModelHash();

  @$internal
  @override
  QrHistoryViewModel create() => QrHistoryViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrHistoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrHistoryState>(value),
    );
  }
}

String _$qrHistoryViewModelHash() =>
    r'39a61df49696c89a496c86127fb6858823a3fcfc';

abstract class _$QrHistoryViewModel extends $Notifier<QrHistoryState> {
  QrHistoryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<QrHistoryState, QrHistoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrHistoryState, QrHistoryState>,
              QrHistoryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
