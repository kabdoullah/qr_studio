import '../../../core/utils/validators.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../models/business_card_data.dart';
import '../models/qr_code_data.dart';
import '../models/qr_type.dart';
import '../models/shared_file.dart';
import '../models/text_qr_data.dart';
import '../services/qr_service.dart';

// Étapes du partage d'un fichier par lien (CV, image de carte de visite).
enum FileStatus { noFile, selecting, fileSelected, uploading, uploaded }

// État d'un fichier partagé : fichier retenu, étape en cours et éventuel
// message d'erreur (sélection refusée ou envoi échoué).
class FileState {
  const FileState({
    this.status = FileStatus.noFile,
    this.file,
    this.errorMessage,
  });

  final FileStatus status;
  final SharedFile? file;
  final String? errorMessage;

  bool get isBusy =>
      status == FileStatus.selecting || status == FileStatus.uploading;

  // Même fichier et même étape, sans message d'erreur.
  FileState withoutError() => FileState(status: status, file: file);

  FileState withError(String message) =>
      FileState(status: status, file: file, errorMessage: message);
}

// Contenu de la carte de visite : coordonnées encodées en vCard, ou image
// de la carte partagée par lien.
enum BusinessCardMode { details, image }

// État de la saisie du contenu, conservé tant que l'utilisateur navigue
// entre le formulaire et le résultat.
class QrContentState {
  const QrContentState({
    this.businessCard = const BusinessCardData(),
    this.businessCardMode = BusinessCardMode.details,
    this.businessCardRevision = 0,
    this.text = const TextQrData(),
    this.cv = const FileState(),
    this.cardImage = const FileState(),
    this.showErrorsFor = const {},
    this.result,
  });

  final BusinessCardData businessCard;
  final BusinessCardMode businessCardMode;

  // Incrémenté quand une carte enregistrée remplace la saisie : le
  // formulaire est alors reconstruit avec les nouvelles valeurs.
  final int businessCardRevision;
  final TextQrData text;
  final FileState cv;
  final FileState cardImage;

  // Types pour lesquels une génération a échoué : leurs erreurs
  // s'affichent toutes, y compris sur les champs jamais touchés. Les autres
  // types n'affichent leurs erreurs qu'après interaction.
  final Set<QrType> showErrorsFor;

  final QrCodeData? result;

  FileState fileState(SharedFileKind kind) => switch (kind) {
    SharedFileKind.cv => cv,
    SharedFileKind.businessCardImage => cardImage,
  };

  // Règles de validation de la carte de visite, partagées par le formulaire
  // (affichage des erreurs) et par le ViewModel (autorisation de générer).
  static String? validateFirstName(String value) =>
      Validators.required(value, 'Veuillez saisir votre prénom.');

  static String? validateLastName(String value) =>
      Validators.required(value, 'Veuillez saisir votre nom.');

  static String? validateEmail(String value) => Validators.email(value);

  static String? validateText(String value) {
    if (value.trim().isEmpty) return 'Veuillez saisir un texte.';
    if (!QrService.fitsInQrCode(value)) {
      return 'Ce texte est trop long pour tenir dans un QR Code. '
          'Veuillez le raccourcir.';
    }
    return null;
  }

  // Vérifie le format et la taille d'un fichier sélectionné.
  static String? validateFile(SharedFile file, SharedFileKind kind) {
    if (!kind.acceptsName(file.name)) return kind.wrongFormatMessage;
    if (file.size == 0) return 'Ce fichier est vide.';
    if (file.size > SharedFileKind.maxSizeBytes) {
      return 'Votre fichier est trop volumineux.\n'
          'La taille maximale est de '
          '${formatFileSize(SharedFileKind.maxSizeBytes)}.';
    }
    return null;
  }

  bool get isTextValid => validateText(text.text) == null;

  static bool isValidBusinessCard(BusinessCardData card) =>
      validateFirstName(card.firstName) == null &&
      validateLastName(card.lastName) == null &&
      validateEmail(card.email) == null;

  bool get isBusinessCardValid => isValidBusinessCard(businessCard);

  QrContentState copyWith({
    BusinessCardData? businessCard,
    BusinessCardMode? businessCardMode,
    int? businessCardRevision,
    TextQrData? text,
    FileState? cv,
    FileState? cardImage,
    Set<QrType>? showErrorsFor,
    QrCodeData? result,
  }) {
    return QrContentState(
      businessCard: businessCard ?? this.businessCard,
      businessCardMode: businessCardMode ?? this.businessCardMode,
      businessCardRevision: businessCardRevision ?? this.businessCardRevision,
      text: text ?? this.text,
      cv: cv ?? this.cv,
      cardImage: cardImage ?? this.cardImage,
      showErrorsFor: showErrorsFor ?? this.showErrorsFor,
      result: result ?? this.result,
    );
  }

  QrContentState withFileState(SharedFileKind kind, FileState file) =>
      switch (kind) {
        SharedFileKind.cv => copyWith(cv: file),
        SharedFileKind.businessCardImage => copyWith(cardImage: file),
      };
}
