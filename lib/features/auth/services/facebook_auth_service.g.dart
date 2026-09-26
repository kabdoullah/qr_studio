// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'facebook_auth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(facebookAuthService)
final facebookAuthServiceProvider = FacebookAuthServiceProvider._();

final class FacebookAuthServiceProvider
    extends
        $FunctionalProvider<
          FacebookAuthService,
          FacebookAuthService,
          FacebookAuthService
        >
    with $Provider<FacebookAuthService> {
  FacebookAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'facebookAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$facebookAuthServiceHash();

  @$internal
  @override
  $ProviderElement<FacebookAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FacebookAuthService create(Ref ref) {
    return facebookAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FacebookAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FacebookAuthService>(value),
    );
  }
}

String _$facebookAuthServiceHash() =>
    r'2556bed577218f97fe18d585d89141b5c99ff932';
