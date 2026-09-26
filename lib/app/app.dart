import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/viewmodels/auth_view_model.dart';
import '../features/qr_generator/viewmodels/qr_content_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// Racine de l'application : thème Material 3 et navigation GoRouter.
class QrStudioApp extends ConsumerWidget {
  const QrStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Déconnexion : la saisie du compte précédent ne doit pas rester en
    // mémoire.
    ref.listen(authViewModelProvider.select((s) => s.isAuthenticated), (
      wasAuthenticated,
      isAuthenticated,
    ) {
      if (wasAuthenticated == true && !isAuthenticated) {
        ref.read(qrContentViewModelProvider.notifier).startOver();
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
