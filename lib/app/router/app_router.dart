import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/qr_generator/services/business_card_directory_service.dart';
import '../../features/qr_generator/viewmodels/qr_content_view_model.dart';
import '../../features/qr_generator/viewmodels/qr_generator_view_model.dart';
import '../../features/qr_generator/views/qr_content_view.dart';
import '../../features/qr_generator/views/qr_generator_view.dart';
import '../../features/qr_generator/views/qr_result_view.dart';
import '../../features/qr_generator/views/saved_cards_view.dart';

// Chemins de navigation de l'application.
abstract final class AppRoutes {
  static const String home = '/';
  static const String content = '/qr/content';
  static const String result = '/qr/result';
  static const String savedCards = '/qr/cards';
}

// Routeur exposé via Riverpod pour pouvoir être surchargé dans les tests.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
