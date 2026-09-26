// Sécurité d'un réseau Wi-Fi. Le format standard des QR Codes Wi-Fi ne
// distingue que `WEP`, `WPA` (qui couvre WPA2 et WPA3) et `nopass`.
enum WifiSecurity {
  none(apiName: 'none', label: 'Aucune (réseau ouvert)', qrCode: 'nopass'),
  wep(apiName: 'WEP', label: 'WEP', qrCode: 'WEP'),
  wpa(apiName: 'WPA', label: 'WPA', qrCode: 'WPA'),
  wpa2(apiName: 'WPA2', label: 'WPA2', qrCode: 'WPA'),
  wpa3(apiName: 'WPA3', label: 'WPA3', qrCode: 'WPA');

  const WifiSecurity({
    required this.apiName,
    required this.label,
    required this.qrCode,
  });

  final String apiName;
  final String label;

  // Valeur du champ `T:` du QR Code.
  final String qrCode;

  bool get needsPassword => this != none;

  static WifiSecurity fromApiName(String? name) =>
      values.firstWhere((s) => s.apiName == name, orElse: () => wpa2);
}

// Réseau Wi-Fi partagé. Le mot de passe est une donnée sensible : il ne
// sert qu'à construire le QR Code et n'apparaît jamais dans les logs
// (`toString` ne l'inclut pas).
class WifiQrData {
  const WifiQrData({
    this.ssid = '',
    this.password = '',
    this.security = WifiSecurity.wpa2,
    this.hidden = false,
  });

  // Limites de la norme Wi-Fi, identiques à celles du serveur.
  static const int maxSsidLength = 32;
  static const int maxPasswordLength = 63;
  static const int minWpaPasswordLength = 8;

  final String ssid;
  final String password;
  final WifiSecurity security;
  final bool hidden;

  WifiQrData copyWith({
    String? ssid,
    String? password,
    WifiSecurity? security,
    bool? hidden,
  }) {
    return WifiQrData(
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      security: security ?? this.security,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, Object?> toJson() => {
    'ssid': ssid,
    'security': security.apiName,
    'password': security.needsPassword ? password : '',
    'hidden': hidden,
  };

  factory WifiQrData.fromJson(Map<String, Object?> json) => WifiQrData(
    ssid: json['ssid'] is String ? json['ssid'] as String : '',
    password: json['password'] is String ? json['password'] as String : '',
    security: WifiSecurity.fromApiName(json['security'] as String?),
    hidden: json['hidden'] == true,
  );

  @override
  String toString() => 'WifiQrData(ssid: $ssid, security: ${security.name})';
}
