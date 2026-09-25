import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

// Par défaut, le retour du focus sur la page vaut annulation si le fichier
// n'est pas arrivé en 500 ms. Sur iOS, le fichier arrive souvent plus tard
// (copie, conversion HEIC) et le choix était perdu : seul l'événement
// `cancel` du navigateur signale désormais une annulation.
const WebOptions pickerWebOptions = FilePickerWebOptions(
  cancelUploadOnWindowBlur: false,
);
