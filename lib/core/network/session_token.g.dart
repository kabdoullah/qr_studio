// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_token.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionToken)
final sessionTokenProvider = SessionTokenProvider._();

final class SessionTokenProvider
    extends $NotifierProvider<SessionToken, AuthTokens?> {
  SessionTokenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionTokenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionTokenHash();

  @$internal
  @override
  SessionToken create() => SessionToken();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthTokens? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthTokens?>(value),
    );
  }
}

String _$sessionTokenHash() => r'9a4fcc3ee531d1cb69afc11a0614033714c54ede';

abstract class _$SessionToken extends $Notifier<AuthTokens?> {
  AuthTokens? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthTokens?, AuthTokens?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthTokens?, AuthTokens?>,
              AuthTokens?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
