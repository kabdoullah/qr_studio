import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/brand_mark.dart';
import '../../features/auth/viewmodels/auth_view_model.dart';
import '../theme/app_dimens.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/qr_generator/services/business_card_directory_service.dart';
import '../../features/qr_generator/viewmodels/qr_content_view_model.dart';
import '../../features/qr_generator/viewmodels/qr_generator_view_model.dart';
import '../../features/qr_generator/views/qr_content_view.dart';
import '../../features/qr_generator/views/qr_generator_view.dart';
import '../../features/qr_generator/views/qr_result_view.dart';
import '../../features/qr_generator/views/saved_cards_view.dart';
import '../../features/qr_history/views/qr_history_view.dart';

part 'app_router.g.dart';

// Chemins de navigation de l'application.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String content = '/qr/content';
  static const String result = '/qr/result';
  static const String savedCards = '/qr/cards';
  static const String history = '/history';
}

// Écran d'accès selon la session : vérification en cours (`/splash`),
// connexion (`/login`, `/register`) ou application. Renvoie `null` si
// `location` convient déjà, ce qui évite toute boucle de redirection.
@visibleForTesting
String? authRedirect(AuthStatus status, String location) {
  final onAuthPage =
      location == AppRoutes.login || location == AppRoutes.register;
  return switch (status) {
    AuthStatus.unknown =>
      location == AppRoutes.splash ? null : AppRoutes.splash,
    AuthStatus.unauthenticated => onAuthPage ? null : AppRoutes.login,
    AuthStatus.authenticated =>
      onAuthPage || location == AppRoutes.splash ? AppRoutes.home : null,
  };
}

// Routeur exposé via Riverpod pour pouvoir être surchargé dans les tests.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Réévalue les redirections à chaque changement de session (connexion,
  // déconnexion, session expirée).
  final authStatus = ValueNotifier(ref.read(authViewModelProvider).status);
  ref.listen(
    authViewModelProvider.select((s) => s.status),
    (_, status) => authStatus.value = status,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authStatus,
    redirect: (context, state) =>
        authRedirect(authStatus.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const QrGeneratorView(),
      ),
      // Sans type choisi ni QR généré (lien direct, état perdu), ces écrans
      // n'ont rien à afficher : retour à l'accueil.
      GoRoute(
        path: AppRoutes.content,
        redirect: (context, state) =>
            ref.read(qrGeneratorViewModelProvider) == null
            ? AppRoutes.home
            : null,
        builder: (context, state) => const QrContentView(),
      ),
      GoRoute(
        path: AppRoutes.result,
        redirect: (context, state) =>
            ref.read(qrContentViewModelProvider).result == null
            ? AppRoutes.home
            : null,
        builder: (context, state) => const QrResultView(),
      ),
      GoRoute(
        path: AppRoutes.savedCards,
        redirect: (context, state) =>
            ref.read(businessCardDirectoryProvider) == null
            ? AppRoutes.home
            : null,
        builder: (context, state) => const SavedCardsView(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const QrHistoryView(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authStatus.dispose();
  });
  return router;
}

// Affiché pendant la vérification de la session au démarrage.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(semanticsLabel: 'Chargement'),
            ),
          ],
        ),
      ),
    );
  }
}
