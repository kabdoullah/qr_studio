// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_storage_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileStorageService)
final fileStorageServiceProvider = FileStorageServiceProvider._();

final class FileStorageServiceProvider
    extends
        $FunctionalProvider<
          FileStorageService,
          FileStorageService,
          FileStorageService
        >
    with $Provider<FileStorageService> {
  FileStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStorageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStorageServiceHash();

  @$internal
  @override
  $ProviderElement<FileStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FileStorageService create(Ref ref) {
    return fileStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileStorageService>(value),
    );
  }
}

String _$fileStorageServiceHash() =>
    r'a7a3a2b4e1cfeb1af60ad98bc18368f110c4f7e7';
