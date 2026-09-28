// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installation_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installationStorage)
final installationStorageProvider = InstallationStorageProvider._();

final class InstallationStorageProvider
    extends
        $FunctionalProvider<
          InstallationStorage,
          InstallationStorage,
          InstallationStorage
        >
    with $Provider<InstallationStorage> {
  InstallationStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installationStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installationStorageHash();

  @$internal
  @override
  $ProviderElement<InstallationStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallationStorage create(Ref ref) {
    return installationStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallationStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallationStorage>(value),
    );
  }
}

String _$installationStorageHash() =>
    r'ae4cbc25f7e8b41235b8bde682aa24bf83a33859';
