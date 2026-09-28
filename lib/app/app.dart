import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/viewmodels/auth_view_model.dart';
import '../features/qr_generator/viewmodels/qr_content_view_model.dart';
import '../features/qr_history/services/qr_history_cache.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// Racine de l'application : thème Material 3 et navigation GoRouter.
class QrStudioApp extends ConsumerWidget {
  const QrStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Changement d'utilisateur (déconnexion, connexion à un autre compte) :
    // la saisie et l'historique enregistré du précédent ne doivent rester
    // ni en mémoire ni sur l'appareil. La conversion d'un utilisateur
    // anonyme en compte garde le même `id` : rien n'est effacé.
    ref.listen(authViewModelProvider.select((s) => s.user?.id), (
      previousId,
      userId,
    ) {
      if (previousId != null && userId != previousId) {
        ref.read(qrContentViewModelProvider.notifier).startOver();
        ref.read(qrHistoryCacheProvider).clear();
      }
    });
    return MaterialApp.router(
      title: 'QR Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
