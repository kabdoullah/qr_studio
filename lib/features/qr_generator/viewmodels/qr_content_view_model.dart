import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

import '../models/business_card_data.dart';
import '../models/qr_code_data.dart';
import '../models/qr_type.dart';
import '../models/saved_qr_code.dart';
import '../models/text_qr_data.dart';
import '../models/website_qr_data.dart';
import '../models/wifi_qr_data.dart';
import '../models/shared_file.dart';
import '../models/social_network.dart';
import '../models/social_page_data.dart';
import '../services/file_picker_service.dart';
import '../services/file_storage_service.dart';
import '../services/qr_service.dart';
import '../services/qr_code_service.dart';
import 'qr_content_state.dart';
import 'qr_generator_view_model.dart';

// Gère la saisie, la validation et la génération du QR Code.
class QrContentViewModel extends Notifier<QrContentState> {
  static const String pickFailedMessage =
      'Impossible de sélectionner le fichier.\nVeuillez réessayer.';
  static const String saveUnavailableMessage =
      "L'enregistrement des QR Codes n'est pas encore disponible.\n"
      'Votre QR Code pourra être créé dès son ouverture.';
  static const String saveFailedMessage =
      "Impossible d'enregistrer votre QR Code.\n"
      'Vérifiez votre connexion et réessayez.';

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

  void updateWebsite(WebsiteQrData Function(WebsiteQrData site) update) {
    state = state.copyWith(website: update(state.website));
  }

  void updateWifi(WifiQrData Function(WifiQrData wifi) update) {
    state = state.copyWith(wifi: update(state.wifi));
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

  // Génère le QR Code du type sélectionné et l'enregistre sur le compte
  // (création, ou mise à jour du QR Code en cours de modification). Renvoie
  // `null` en cas d'échec : saisie invalide (les erreurs de ce type
  // deviennent toutes visibles), envoi du fichier ou enregistrement refusé
  // (le message est placé dans l'état).
  Future<QrCodeData?> generateQr() async {
    final type = ref.read(qrGeneratorViewModelProvider);
    if (type == null || state.saving.isSaving) return null;
    state = state.copyWith(saving: const SaveState());

    final linkedKind = switch (type) {
      QrType.cv => SharedFileKind.cv,
      QrType.businessCard
          when state.businessCardMode == BusinessCardMode.image =>
        SharedFileKind.businessCardImage,
      _ => null,
    };
    // Contenu encodé directement dans le QR Code (types statiques).
    final staticPayload = switch (type) {
      QrType.businessCard
          when linkedKind == null && state.isBusinessCardValid =>
        _qrService.generateBusinessCardPayload(state.businessCard),
      QrType.text when state.isTextValid => _qrService.generateTextPayload(
        state.text,
      ),
      QrType.wifi when state.isWifiValid => _qrService.generateWifiPayload(
        state.wifi,
      ),
      _ => null,
    };
    final isValid = switch (type) {
      QrType.cv => true,
      QrType.businessCard when linkedKind != null => true,
      QrType.socialMedia => state.isSocialPageValid,
      QrType.website => state.isWebsiteValid,
      _ =>
        staticPayload != null &&
            // Garde-fou : un contenu trop volumineux ne produirait pas de
            // QR Code.
            QrService.fitsInQrCode(staticPayload),
    };
    final file = isValid && linkedKind != null
        ? await _upload(linkedKind)
        : null;
    if (!isValid || (linkedKind != null && file == null)) {
      state = state.copyWith(
        showErrorsFor: {...state.showErrorsFor, type},
        failedGenerations: state.failedGenerations + 1,
      );
      return null;
    }

    final saved = await _save(type, file);
    if (saved == null) return null;
    final payload =
        staticPayload ??
        switch (type) {
          QrType.socialMedia => _qrService.generateSocialMediaPayload(
            saved.publicUrl,
          ),
          QrType.website => _qrService.generateWebsitePayload(saved.publicUrl),
          _ => _qrService.generateLinkPayload(saved.publicUrl),
        };
    final result = QrCodeData(type: type, payload: payload, file: file);
    state = state.copyWith(result: result, editing: saved);
    return result;
  }

  // Ouvre un QR Code enregistré (historique) : sa saisie remplit le
  // formulaire de son type, et le résultat est prêt à être affiché.
  // Générer à nouveau le mettra à jour (même adresse publique).
  QrCodeData openSaved(SavedQrCode saved) {
    reset();
    ref.read(qrGeneratorViewModelProvider.notifier).selectQrType(saved.type);
    final content = saved.content;
    final result = resultFor(saved);
    final file = result.file;
    final uploaded = FileState(status: FileStatus.uploaded, file: file);

    state = switch (saved.type) {
      QrType.text => state.copyWith(text: TextQrData.fromJson(content)),
      QrType.wifi => state.copyWith(wifi: WifiQrData.fromJson(content)),
      QrType.website => state.copyWith(
        website: WebsiteQrData.fromJson(saved.title, content),
      ),
      QrType.socialMedia => state.copyWith(
        socialPage: SocialPageData.fromJson(saved.title, content),
      ),
      QrType.cv => state.copyWith(cv: uploaded),
      QrType.businessCard when file != null => state.copyWith(
        businessCardMode: BusinessCardMode.image,
        cardImage: uploaded,
      ),
      QrType.businessCard => state.copyWith(
        businessCard: BusinessCardData.fromJson(saved.section('details')),
        businessCardRevision: state.businessCardRevision + 1,
      ),
    };
    state = state.copyWith(result: result, editing: saved);
    return result;
  }

  // QR Code d'un enregistrement, sans modifier la saisie en cours
  // (partage depuis l'historique).
  QrCodeData resultFor(SavedQrCode saved) {
    final content = saved.content;
    final fileId = content['file_id'];
    final file = fileId is String
        ? SharedFile(
            name: content['filename'] is String
                ? content['filename'] as String
                : saved.title,
            // Taille inconnue : le fichier est déjà en ligne.
            size: 0,
            remoteId: fileId,
            remoteUrl: saved.publicUrl,
          )
        : null;
    return QrCodeData(
      type: saved.type,
      payload: _qrService.generateSavedPayload(saved),
      file: file,
    );
  }

  // Met le fichier en ligne si nécessaire et le renvoie avec son identifiant, ou
  // `null` en cas d'échec (le message d'erreur est alors placé dans l'état).
  Future<SharedFile?> _upload(SharedFileKind kind) async {
    final current = state.fileState(kind);
    final file = current.file;
    if (current.isBusy) return null;
    if (file == null) {
      _setFile(kind, current.withError(kind.missingMessage));
      return null;
    }
    if (file.isUploaded) return file;

    _setFile(kind, FileState(status: FileStatus.uploading, file: file));
    try {
      final remote = await ref
          .read(fileStorageServiceProvider)
          .upload(file, kind);
      final uploaded = file.withRemote(remote);
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
              // Les refus du serveur (format, taille, espace plein) ont
              // leur propre message ; les pannes réseau gardent celui du
              // type de fichier.
              : error is ApiException &&
                    error.kind != ApiErrorKind.offline &&
                    error.kind != ApiErrorKind.timeout &&
                    error.kind != ApiErrorKind.server
              ? error.message
              : kind.uploadFailedMessage,
        ),
      );
      return null;
    }
  }

  // Enregistre le QR Code sur le compte, ou renvoie `null` (message
  // d'erreur dans l'état).
  Future<SavedQrCode?> _save(QrType type, SharedFile? file) async {
    final service = ref.read(qrCodeServiceProvider);
    if (service == null) {
      _setSave(SaveState(errorMessage: saveUnavailableMessage, type: type));
      return null;
    }
    final title = _titleFor(type, file);
    final content = _contentFor(type, file);
    final editing = state.editing?.type == type ? state.editing : null;

    _setSave(SaveState(isSaving: true, type: type));
    try {
      final saved = editing == null
          ? await service.create(type, title: title, content: content)
          : await service.update(
              editing.id,
              type,
              title: title,
              content: content,
            );
      _setSave(const SaveState());
      return saved;
    } catch (error, stackTrace) {
      // Jamais le contenu dans les logs (mot de passe Wi-Fi).
      _log("Échec de l'enregistrement (${type.name})", error, stackTrace);
      _setSave(
        SaveState(
          errorMessage: error is ApiException
              ? error.message
              : saveFailedMessage,
          type: type,
        ),
      );
      return null;
    }
  }

  // Titre affiché dans « Mes QR Codes » (100 caractères au plus, comme
  // sur le serveur).
  String _titleFor(QrType type, SharedFile? file) {
    String clip(String text, int max) {
      final line = text.trim().split('\n').first.trim();
      return line.length > max ? '${line.substring(0, max - 1)}…' : line;
    }

    final title = switch (type) {
      QrType.socialMedia => state.socialPage.title,
      QrType.website =>
        state.website.title.trim().isNotEmpty
            ? state.website.title
            : Uri.tryParse(
                    WebsiteQrData.normalizeUrl(state.website.url),
                  )?.host ??
                  '',
      QrType.wifi => 'Wi-Fi ${state.wifi.ssid.trim()}',
      // Début du texte, pour le reconnaître dans la liste.
      QrType.text => clip(state.text.text, 60),
      QrType.cv => file?.name ?? '',
      QrType.businessCard when file != null => type.title,
      QrType.businessCard =>
        '${state.businessCard.firstName.trim()} '
            '${state.businessCard.lastName.trim()}',
    };
    final clipped = clip(title, WebsiteQrData.maxTitleLength);
    return clipped.isEmpty ? type.title : clipped;
  }

  Map<String, Object?> _contentFor(QrType type, SharedFile? file) =>
      switch (type) {
        QrType.text => state.text.toJson(),
        QrType.wifi => state.wifi.toJson(),
        QrType.website => state.website.toJson(),
        QrType.socialMedia => state.socialPage.toJson(),
        QrType.cv => {'file_id': file?.remoteId},
        QrType.businessCard when file != null => {
          'mode': 'image',
          'file_id': file.remoteId,
        },
        QrType.businessCard => {
          'mode': 'details',
          'details': state.businessCard.toJson(),
        },
      };

  void _setSave(SaveState saving) => state = state.copyWith(saving: saving);

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
    case QrType.wifi:
      final wifi = ref.watch(qrContentViewModelProvider.select((s) => s.wifi));
      if (!QrContentState.isValidWifi(wifi)) {
        return const LivePreview.placeholder(
          "Renseignez le nom du réseau et son mot de passe pour voir l'aperçu.",
        );
      }
      return fromPayload(service.generateWifiPayload(wifi));
    // L'adresse publique d'un fichier, d'une page ou d'un site n'existe
    // qu'après l'enregistrement.
    case QrType.cv || QrType.socialMedia || QrType.website || null:
      return null;
  }
});
