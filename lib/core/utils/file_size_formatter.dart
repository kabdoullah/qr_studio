// Formate une taille de fichier lisible par l'utilisateur (ex. « 1.8 MB »).
String formatFileSize(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${_oneDecimal(bytes / mb)} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

// Une décimale, sans « .0 » superflu : 10 MB, 1.8 MB.
String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}
