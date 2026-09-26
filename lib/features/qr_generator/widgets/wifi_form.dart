import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/visibility_toggle.dart';
import '../models/qr_type.dart';
import '../models/wifi_qr_data.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Réseau Wi-Fi : le QR Code contient les informations de connexion au
// format standard (l'aperçu en direct est affiché par la vue).
class WifiForm extends ConsumerStatefulWidget {
  const WifiForm({super.key});

  @override
  ConsumerState<WifiForm> createState() => _WifiFormState();
}

class _WifiFormState extends ConsumerState<WifiForm> {
  late final TextEditingController _password;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    // Valeur initiale : conservée lorsque l'utilisateur revient modifier.
    _password = TextEditingController(
      text: ref.read(qrContentViewModelProvider).wifi.password,
    );
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = ref.read(qrContentViewModelProvider).wifi;
    final security = ref.watch(
      qrContentViewModelProvider.select((s) => s.wifi.security),
    );
    final hidden = ref.watch(
      qrContentViewModelProvider.select((s) => s.wifi.hidden),
    );
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.wifi),
      ),
    );
    final viewModel = ref.read(qrContentViewModelProvider.notifier);

    return Form(
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Votre réseau',
            description:
                'Partagez votre connexion en un scan : il suffit de scanner '
                'le QR Code pour se connecter.',
          ),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: initial.ssid,
            decoration: const InputDecoration(
              labelText: 'Nom du réseau (SSID) *',
              hintText: 'Wi-Fi Maison',
            ),
            maxLength: WifiQrData.maxSsidLength,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            onChanged: (v) => viewModel.updateWifi((w) => w.copyWith(ssid: v)),
            validator: (v) => QrContentState.validateWifiSsid(v ?? ''),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<WifiSecurity>(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: security,
            // Libellés sur toute la largeur, coupés si le texte est agrandi.
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sécurité'),
            items: [
              for (final value in WifiSecurity.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(value.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              viewModel.updateWifi((w) => w.copyWith(security: value));
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _password,
            enabled: security.needsPassword,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: WifiQrData.maxPasswordLength,
            decoration: InputDecoration(
              labelText: security.needsPassword
                  ? 'Mot de passe *'
                  : 'Mot de passe (réseau ouvert)',
              suffixIcon: security.needsPassword
                  ? VisibilityToggle(
                      obscured: _obscured,
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (v) =>
                viewModel.updateWifi((w) => w.copyWith(password: v)),
            validator: (v) =>
                QrContentState.validateWifiPassword(v ?? '', security),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          CheckboxListTile(
            value: hidden,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Réseau masqué'),
            subtitle: const Text("Le réseau n'apparaît pas dans la liste."),
            onChanged: (value) =>
                viewModel.updateWifi((w) => w.copyWith(hidden: value ?? false)),
          ),
        ],
      ),
    );
  }
}
