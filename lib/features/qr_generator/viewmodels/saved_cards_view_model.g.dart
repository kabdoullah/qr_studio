// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_cards_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SavedCardsViewModel)
final savedCardsViewModelProvider = SavedCardsViewModelProvider._();

final class SavedCardsViewModelProvider
    extends
        $AsyncNotifierProvider<SavedCardsViewModel, List<SavedBusinessCard>> {
  SavedCardsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'savedCardsViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedCardsViewModelHash();

  @$internal
  @override
  SavedCardsViewModel create() => SavedCardsViewModel();
}

String _$savedCardsViewModelHash() =>
    r'35c0becbb590f1785e6b3b4b1b293a607902c000';

abstract class _$SavedCardsViewModel
    extends $AsyncNotifier<List<SavedBusinessCard>> {
  FutureOr<List<SavedBusinessCard>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<SavedBusinessCard>>,
              List<SavedBusinessCard>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SavedBusinessCard>>,
                List<SavedBusinessCard>
              >,
              AsyncValue<List<SavedBusinessCard>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CardPublishViewModel)
final cardPublishViewModelProvider = CardPublishViewModelProvider._();

final class CardPublishViewModelProvider
    extends $NotifierProvider<CardPublishViewModel, bool> {
  CardPublishViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardPublishViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardPublishViewModelHash();

  @$internal
  @override
  CardPublishViewModel create() => CardPublishViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cardPublishViewModelHash() =>
    r'651aa88ba3b827d3c4080ab731721d19eec2ca3f';

abstract class _$CardPublishViewModel extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
