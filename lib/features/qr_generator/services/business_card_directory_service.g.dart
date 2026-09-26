// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_card_directory_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessCardDirectory)
final businessCardDirectoryProvider = BusinessCardDirectoryProvider._();

final class BusinessCardDirectoryProvider
    extends
        $FunctionalProvider<
          BusinessCardDirectoryService?,
          BusinessCardDirectoryService?,
          BusinessCardDirectoryService?
        >
    with $Provider<BusinessCardDirectoryService?> {
  BusinessCardDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessCardDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessCardDirectoryHash();

  @$internal
  @override
  $ProviderElement<BusinessCardDirectoryService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessCardDirectoryService? create(Ref ref) {
    return businessCardDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessCardDirectoryService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessCardDirectoryService?>(
        value,
      ),
    );
  }
}

String _$businessCardDirectoryHash() =>
    r'1e7ffa278e89c865af3ed16f03e3e4e27bfa8e04';
