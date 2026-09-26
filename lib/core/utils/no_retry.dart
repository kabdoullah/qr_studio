// Pour `@Riverpod(retry: noRetry)` : pas de nouvel essai automatique après
// une erreur ; l'utilisateur voit l'erreur et choisit de réessayer.
Duration? noRetry(int retryCount, Object error) => null;
