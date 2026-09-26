import '../../../core/utils/validators.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../models/business_card_data.dart';
import '../models/qr_code_data.dart';
import '../models/qr_type.dart';
import '../models/shared_file.dart';
import '../models/social_network.dart';
import '../models/saved_qr_code.dart';
import '../models/social_page_data.dart';
import '../models/text_qr_data.dart';
import '../models/website_qr_data.dart';
import '../models/wifi_qr_data.dart';
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

// Enregistrement du QR Code sur le compte : en cours, ou message d'erreur
// de la dernière tentative (pour le type `type`).
class SaveState {
  const SaveState({this.isSaving = false, this.errorMessage, this.type});

  final bool isSaving;
  final String? errorMessage;
  final QrType? type;
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
    this.socialPage = const SocialPageData(),
    this.website = const WebsiteQrData(),
    this.wifi = const WifiQrData(),
    this.saving = const SaveState(),
    this.editing,
    this.showErrorsFor = const {},
    this.failedGenerations = 0,
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
  final SocialPageData socialPage;
  final WebsiteQrData website;
  final WifiQrData wifi;
  final SaveState saving;

  // QR Code enregistré en cours de modification : générer le met à jour
  // (même adresse publique) au lieu d'en créer un nouveau.
  final SavedQrCode? editing;

  // Types pour lesquels une génération a échoué : leurs erreurs
  // s'affichent toutes, y compris sur les champs jamais touchés. Les autres
  // types n'affichent leurs erreurs qu'après interaction.
  final Set<QrType> showErrorsFor;

  // Incrémenté à chaque génération refusée : le formulaire amène alors la
  // première erreur à l'écran, même si l'utilisateur a défilé plus bas.
  final int failedGenerations;

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

  static String? validateSocialTitle(String value) {
    if (value.trim().isEmpty) return 'Veuillez saisir un titre.';
    if (value.trim().length > SocialPageData.maxTitleLength) {
      return 'Le titre ne doit pas dépasser '
          '${SocialPageData.maxTitleLength} caractères.';
    }
    return null;
  }

  static String? validateSocialBio(String value) =>
      value.trim().length > SocialPageData.maxBioLength
      ? 'La description ne doit pas dépasser '
            '${SocialPageData.maxBioLength} caractères.'
      : null;

  static String? validateSocialLink(SocialNetwork network, String value) {
    if (value.trim().isEmpty) return 'Veuillez compléter ce lien.';
    return network.toUrl(value) == null ? network.invalidMessage : null;
  }

  static String? validateSocialLinks(List<SocialLink> links) =>
      links.isEmpty ? 'Ajoutez au moins un réseau.' : null;

  static String? validateWebsiteTitle(String value) =>
      value.trim().length > WebsiteQrData.maxTitleLength
      ? 'Le titre ne doit pas dépasser '
            '${WebsiteQrData.maxTitleLength} caractères.'
      : null;

  // Même règle que le serveur : adresse web complète, en https (http est
  // refusé en production).
  static String? validateWebsiteUrl(String value) {
    if (value.trim().isEmpty) return "Veuillez saisir l'adresse du site.";
    final url = WebsiteQrData.normalizeUrl(value);
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.isScheme('https') || uri.isScheme('http')) &&
        uri.host.contains('.') &&
        uri.userInfo.isEmpty &&
        !RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(url) &&
        url.length <= WebsiteQrData.maxUrlLength;
    return valid ? null : 'Adresse du site invalide (ex. https://exemple.com).';
  }

  static bool isValidWebsite(WebsiteQrData site) =>
      validateWebsiteTitle(site.title) == null &&
      validateWebsiteUrl(site.url) == null;

  bool get isWebsiteValid => isValidWebsite(website);

  static String? validateWifiSsid(String value) {
    if (value.trim().isEmpty) return 'Veuillez saisir le nom du réseau.';
    if (value.length > WifiQrData.maxSsidLength) {
      return 'Le nom du réseau ne doit pas dépasser '
          '${WifiQrData.maxSsidLength} caractères.';
    }
    return null;
  }

  static String? validateWifiPassword(String value, WifiSecurity security) {
    if (!security.needsPassword) return null;
    if (value.isEmpty) return 'Veuillez saisir le mot de passe.';
    if (security != WifiSecurity.wep &&
        value.length < WifiQrData.minWpaPasswordLength) {
      return 'Le mot de passe doit contenir au moins '
          '${WifiQrData.minWpaPasswordLength} caractères.';
    }
    return null;
  }

  static bool isValidWifi(WifiQrData wifi) =>
      validateWifiSsid(wifi.ssid) == null &&
      validateWifiPassword(wifi.password, wifi.security) == null;

  bool get isWifiValid => isValidWifi(wifi);

  static bool isValidSocialPage(SocialPageData page) =>
      validateSocialTitle(page.title) == null &&
      validateSocialBio(page.bio) == null &&
      validateSocialLinks(page.links) == null &&
      page.links.every((l) => validateSocialLink(l.network, l.value) == null);

  bool get isSocialPageValid => isValidSocialPage(socialPage);

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
    SocialPageData? socialPage,
    WebsiteQrData? website,
    WifiQrData? wifi,
    SaveState? saving,
    SavedQrCode? editing,
    Set<QrType>? showErrorsFor,
    int? failedGenerations,
    QrCodeData? result,
  }) {
    return QrContentState(
      businessCard: businessCard ?? this.businessCard,
      businessCardMode: businessCardMode ?? this.businessCardMode,
      businessCardRevision: businessCardRevision ?? this.businessCardRevision,
      text: text ?? this.text,
      cv: cv ?? this.cv,
      cardImage: cardImage ?? this.cardImage,
      socialPage: socialPage ?? this.socialPage,
      website: website ?? this.website,
      wifi: wifi ?? this.wifi,
      saving: saving ?? this.saving,
      editing: editing ?? this.editing,
      showErrorsFor: showErrorsFor ?? this.showErrorsFor,
      failedGenerations: failedGenerations ?? this.failedGenerations,
      result: result ?? this.result,
    );
  }

  QrContentState withFileState(SharedFileKind kind, FileState file) =>
      switch (kind) {
        SharedFileKind.cv => copyWith(cv: file),
        SharedFileKind.businessCardImage => copyWith(cardImage: file),
      };
}
