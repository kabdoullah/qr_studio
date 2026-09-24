"""Limitation du nombre d'envois (en mémoire, une seule instance)."""

import time
from collections import defaultdict, deque
from typing import Callable, Deque, Dict

_GLOBAL_KEY = "*"


class UploadRateLimiter:
    def __init__(
        self,
        per_client: int,
        total: int,
        window_seconds: float = 3600,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._per_client = per_client
        self._total = total
        self._window = window_seconds
        self._clock = clock
        self._hits: Dict[str, Deque[float]] = defaultdict(deque)

    def _recent(self, key: str, now: float) -> Deque[float]:
        hits = self._hits[key]
        while hits and now - hits[0] >= self._window:
            hits.popleft()
        return hits

    def allow(self, client: str) -> bool:
        """Enregistre un envoi si les deux limites le permettent."""
        now = self._clock()
        client_hits = self._recent(client, now)
        global_hits = self._recent(_GLOBAL_KEY, now)
        if len(client_hits) >= self._per_client or len(global_hits) >= self._total:
            return False
        client_hits.append(now)
        global_hits.append(now)
        # Évite de conserver indéfiniment les clients inactifs.
        if len(self._hits) > 10_000:
            for key in [k for k, v in self._hits.items() if not v]:
                del self._hits[key]
        return True
