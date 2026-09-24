import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_card_data.dart';
import '../models/qr_code_data.dart';
import '../models/qr_type.dart';
import '../models/text_qr_data.dart';
import '../models/shared_file.dart';
import '../models/social_network.dart';
import '../models/social_page_data.dart';
import '../services/file_picker_service.dart';
import '../services/file_storage_service.dart';
import '../services/qr_service.dart';
import '../services/social_page_service.dart';
import 'qr_content_state.dart';
import 'qr_generator_view_model.dart';

// Gère la saisie, la validation et la génération du QR Code.
class QrContentViewModel extends Notifier<QrContentState> {
  static const String pickFailedMessage =
      'Impossible de sélectionner le fichier.\nVeuillez réessayer.';
  static const String publishUnavailableMessage =
      "La publication des pages n'est pas encore disponible.\n"
      'Votre QR Code pourra être créé dès son ouverture.';
  static const String publishFailedMessage =
      'Impossible de publier la page.\n'
      'Vérifiez votre connexion et réessayez.';
  static const String publishTooManyMessage =
      "Trop d'envois. Réessayez plus tard.";

  @override
  QrContentState build() => const QrContentState();

  QrService get _qrService => ref.read(qrServiceProvider);

  // Applique une modification à la carte de visite, par exemple :
  // `updateBusinessCard((card) => card.copyWith(firstName: value))`.
  void updateBusinessCard(
    BusinessCardData Function(BusinessCardData card) update,
  ) {
    state = state.copyWith(businessCard: update(state.businessCard));
  }

  // Remplace la saisie par une carte enregistrée.
  void loadBusinessCard(BusinessCardData card) {
    state = state.copyWith(
      businessCard: card,
      businessCardMode: BusinessCardMode.details,
      businessCardRevision: state.businessCardRevision + 1,
      showErrorsFor: {...state.showErrorsFor}..remove(QrType.businessCard),
    );
  }

  // Bascule entre les coordonnées et l'image de la carte. La saisie de
  // l'autre mode est conservée.
  void setBusinessCardMode(BusinessCardMode mode) {
    state = state.copyWith(businessCardMode: mode);
  }

  void updateText(String text) {
    state = state.copyWith(text: TextQrData(text: text));
  }

  void updateSocialPage(SocialPageData Function(SocialPageData page) update) {
    state = state.copyWith(socialPage: update(state.socialPage));
  }

  // Ajoute une ligne vide pour ce réseau (dans la limite autorisée).
  void addSocialLink(SocialNetwork network) {
    final links = state.socialPage.links;
    if (links.length >= SocialPageData.maxLinks) return;
    final id = links.fold(0, (max, l) => l.id > max ? l.id : max) + 1;
    updateSocialPage(
      (page) => page.copyWith(
        links: [
          ...links,
          SocialLink(id: id, network: network),
        ],
      ),
    );
  }

  void updateSocialLink(int id, String value) {
    updateSocialPage(
      (page) => page.copyWith(
        links: [
          for (final l in page.links) l.id == id ? l.withValue(value) : l,
        ],
      ),
    );
  }

  void removeSocialLink(int id) {
    updateSocialPage(
      (page) => page.copyWith(
        links: [
          for (final l in page.links)
            if (l.id != id) l,
        ],
      ),
    );
  }

  Future<void> pickCv() => _pickFile(SharedFileKind.cv);

  Future<void> pickCardImage() => _pickFile(SharedFileKind.businessCardImage);

  // Ouvre le sélecteur adapté. Un fichier refusé ou une annulation conserve
  // le fichier précédemment retenu.
  Future<void> _pickFile(SharedFileKind kind) async {
    final previous = state.fileState(kind);
    if (previous.isBusy) return;
    _setFile(
      kind,
      FileState(status: FileStatus.selecting, file: previous.file),
    );

    try {
      final picker = ref.read(filePickerServiceProvider);
      final file = await switch (kind) {
        SharedFileKind.cv => picker.pickPdf(),
        SharedFileKind.businessCardImage => picker.pickImage(),
      };
      if (file == null) {
        _setFile(kind, previous.withoutError());
        return;
      }
      final error = QrContentState.validateFile(file, kind);
      _setFile(
        kind,
        error == null
            ? FileState(status: FileStatus.fileSelected, file: file)
            : previous.withError(error),
      );
    } catch (error, stackTrace) {
      _log('Échec de la sélection (${kind.name})', error, stackTrace);
      _setFile(kind, previous.withError(pickFailedMessage));
    }
  }

  // Génère le QR Code du type sélectionné. Renvoie `null` si le contenu
  // est invalide ; les erreurs de ce type deviennent alors toutes visibles.
  Future<QrCodeData?> generateQr() async {
    final type = ref.read(qrGeneratorViewModelProvider);
    if (type == null) return null;

    final linkedKind = switch (type) {
      QrType.cv => SharedFileKind.cv,
      QrType.businessCard
          when state.businessCardMode == BusinessCardMode.image =>
        SharedFileKind.businessCardImage,
      _ => null,
    };
    final file = linkedKind == null ? null : await _upload(linkedKind);
    final pageUrl = type == QrType.socialPage
        ? await _publishSocialPage()
        : null;
    final payload = switch (type) {
      _ when file != null => _qrService.generateLinkPayload(file.remoteUrl!),
      _ when pageUrl != null => _qrService.generateLinkPayload(pageUrl),
      QrType.businessCard
          when linkedKind == null && state.isBusinessCardValid =>
        _qrService.generateBusinessCardPayload(state.businessCard),
      QrType.text when state.isTextValid => _qrService.generateTextPayload(
        state.text,
      ),
      _ => null,
    };

    // Garde-fou : un contenu trop volumineux ne produirait pas de QR Code.
    if (payload == null || !QrService.fitsInQrCode(payload)) {
      state = state.copyWith(
        showErrorsFor: {...state.showErrorsFor, type},
        failedGenerations: state.failedGenerations + 1,
      );
      return null;
    }

    final result = QrCodeData(type: type, payload: payload, file: file);
    state = state.copyWith(result: result);
    return result;
  }

  // Met le fichier en ligne si nécessaire et le renvoie avec son URL, ou
  // `null` en cas d'échec (le message d'erreur est alors placé dans l'état).
  Future<SharedFile?> _upload(SharedFileKind kind) async {
    final current = state.fileState(kind);
    final file = current.file;
    if (current.isBusy) return null;
    if (file == null) {
      _setFile(kind, current.withError(kind.missingMessage));
      return null;
    }
    if (file.remoteUrl != null) return file;

    _setFile(kind, FileState(status: FileStatus.uploading, file: file));
    try {
      final url = await ref.read(fileStorageServiceProvider).upload(file, kind);
      final uploaded = file.withRemoteUrl(url);
      _setFile(kind, FileState(status: FileStatus.uploaded, file: uploaded));
      return uploaded;
    } catch (error, stackTrace) {
      final unavailable = error is FileStorageUnavailableException;
      if (!unavailable) {
        _log("Échec de l'envoi (${kind.name})", error, stackTrace);
      }
      _setFile(
        kind,
        FileState(
          status: FileStatus.fileSelected,
          file: file,
          errorMessage: unavailable
              ? kind.unavailableMessage
              : kind.uploadFailedMessage,
        ),
      );
      return null;
    }
  }

  // Publie la page si elle est valide et renvoie son URL, ou `null` (le
  // message d'erreur éventuel est alors placé dans l'état).
  Future<String?> _publishSocialPage() async {
    if (state.socialPagePublish.isPublishing || !state.isSocialPageValid) {
      return null;
    }
    final service = ref.read(socialPageServiceProvider);
    if (service == null) {
      _setPublish(const PublishState(errorMessage: publishUnavailableMessage));
      return null;
    }

    _setPublish(const PublishState(isPublishing: true));
    try {
      final url = await service.publish(state.socialPage);
      _setPublish(const PublishState());
      return url;
    } catch (error, stackTrace) {
      _log('Échec de la publication de la page', error, stackTrace);
      final tooMany = error is SocialPageException && error.statusCode == 429;
      _setPublish(
        PublishState(
          errorMessage: tooMany ? publishTooManyMessage : publishFailedMessage,
        ),
      );
      return null;
    }
  }

  void _setPublish(PublishState publish) =>
      state = state.copyWith(socialPagePublish: publish);

  void _setFile(SharedFileKind kind, FileState file) =>
      state = state.withFileState(kind, file);

  // Détails techniques réservés aux logs de développement.
  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'QrContentViewModel',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void reset() => state = const QrContentState();

  // « Créer un nouveau QR Code » : efface la saisie et le type choisi.
  void startOver() {
    reset();
    ref.read(qrGeneratorViewModelProvider.notifier).reset();
  }
}

final qrContentViewModelProvider =
    NotifierProvider<QrContentViewModel, QrContentState>(
      QrContentViewModel.new,
    );

// Aperçu affiché pendant la saisie : soit un payload prêt à être rendu,
// soit un message expliquant pourquoi le QR Code n'est pas encore visible.
class LivePreview {
  const LivePreview.ready(String this.payload) : message = null;
  const LivePreview.placeholder(String this.message) : payload = null;

  final String? payload;
  final String? message;
}

// Aperçu en direct du type sélectionné, ou `null` si ce contenu n'en
// propose pas (un fichier n'a pas d'URL avant sa mise en ligne). Recalculé uniquement
// quand le contenu du type affiché change.
final livePreviewProvider = Provider<LivePreview?>((ref) {
  const tooLong =
      'Ces informations sont trop longues pour tenir dans un QR Code. '
      'Veuillez raccourcir certains champs.';
  final service = ref.read(qrServiceProvider);

  LivePreview fromPayload(String payload) => QrService.fitsInQrCode(payload)
      ? LivePreview.ready(payload)
      : const LivePreview.placeholder(tooLong);

  switch (ref.watch(qrGeneratorViewModelProvider)) {
    case QrType.text:
      final text = ref.watch(qrContentViewModelProvider.select((s) => s.text));
      if (text.text.trim().isEmpty) {
        return const LivePreview.placeholder(
          'Votre QR Code apparaîtra ici pendant la saisie.',
        );
      }
      final error = QrContentState.validateText(text.text);
      return error == null
          ? fromPayload(service.generateTextPayload(text))
          : LivePreview.placeholder(error);
    case QrType.businessCard:
      final mode = ref.watch(
        qrContentViewModelProvider.select((s) => s.businessCardMode),
      );
      // L'image n'a pas d'URL avant sa mise en ligne.
      if (mode == BusinessCardMode.image) return null;
      final card = ref.watch(
        qrContentViewModelProvider.select((s) => s.businessCard),
      );
      if (!QrContentState.isValidBusinessCard(card)) {
        return const LivePreview.placeholder(
          "Renseignez au moins votre prénom et votre nom pour voir l'aperçu.",
        );
      }
      return fromPayload(service.generateBusinessCardPayload(card));
    // L'URL d'un fichier ou d'une page n'existe qu'après sa mise en ligne.
    case QrType.cv || QrType.socialPage || null:
      return null;
  }
});
