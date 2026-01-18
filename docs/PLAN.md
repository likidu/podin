Podcast Index Client for Symbian Belle (Qt 4.7+ + QML)
======================================================

Milestone 0 — Scope, constraints, and API mapping
- Goals: playback-centric, no social/account sync, local-only subscriptions/downloads.
- Targets: Symbian Belle, Qt 4.7+, QML 1.1; use existing TLS 1.2 scaffold.
- API decisions (initial set):
  - Search: /search/byterm
  - Podcast details: /podcasts/byfeedid or /podcasts/byguid
  - Episodes: /episodes/byfeedid
  - Optional discovery: /recent/episodes, /trending
- Auth strategy:
  - Now: API key/secret stored locally (settings or config).
  - Later: "Podcast Index login" = user-provided API key/secret UI.
- Deliverable: short spec doc mapping screens to API endpoints and required fields.
- Acceptance: spec lists minimal fields needed per endpoint and how they map to UI.

Milestone 1 — App architecture and data flow
- Define a clean separation:
  - QML UI layer
  - C++ API client (QNetworkAccessManager + TLS v1.2)
  - Data models exposed to QML
  - Storage layer (SQLite via QtSql or lightweight JSON files)
- JSON parsing plan (Qt 4.7):
  - Use a small Qt 4 JSON lib (QJson) or parse via QScriptEngine to QVariant.
- Implement a request wrapper with:
  - Base URL, headers, error handling, timeouts, retries (basic).
  - Hook points for auth/signing headers.
- Deliverable: minimal C++ service skeleton exposing "search()", "getPodcast()", "getEpisodes()".
- Acceptance: can compile and run with mock/fake JSON and show data in QML list.

Milestone 2 — Minimal UI shell in QML
- QML screens (simple, phone-friendly):
  1) Search screen (text input + results list)
  2) Podcast detail (art, title, description, subscribe)
  3) Episode list (title, date, duration)
  4) Player (title, progress, play/pause, seek)
- Use standard Symbian components where possible; keep layout light.
- Add loading and error states (empty list, API error).
- Deliverable: QML screens wired to placeholder models.
- Acceptance: navigation flow works with mock data; no crashes on back/forward.

Milestone 3 — Core data + playback
- Implement live API fetch:
  - Search by term -> list of podcasts
  - Podcast detail -> episodes
- Models:
  - PodcastListModel
  - EpisodeListModel
- Playback:
  - QMediaPlayer (QtMultimediaKit) or Symbian-supported backend.
  - Play streaming URLs from Podcast Index episode data.
  - Track current time, duration, buffer state.
- Deliverable: Search -> open podcast -> play episode.
- Acceptance: audio plays, pause/resume/seek works, UI updates progress.

Milestone 4 — Local state and offline basics
- Storage:
  - Subscriptions table: feedId, title, image, lastUpdated
  - Episode table: id/guid, feedId, title, audioUrl, duration, localPath, playedPosition
- Features:
  - Subscribe/unsubscribe
  - Recent list (last played / recently fetched)
  - Resume playback position
- Optional: episode download (store file path, basic progress)
- Deliverable: local subscription management and playback resume.
- Acceptance: subscribe persists across app restart; resume from last position.

Milestone 5 — Robustness and UX polish
- Error handling: network failures, missing audio URLs, rate limits.
- Offline behavior: show cached subscriptions/episodes.
- Performance: image caching (local file cache), lazy loading for lists.
- Bandwidth controls: "stream only" vs "download on tap".
- Deliverable: smoother user experience without adding extra features.
- Acceptance: app does not hang on bad network; graceful fallback UI.

Milestone 6 — Authentication and future "login" hook
- Add a settings screen for API key + secret (optional now, required later).
- Implement signing helper (HMAC SHA1 per Podcast Index spec):
  - X-Auth-Key, X-Auth-Date, Authorization
- Keep it modular to allow later "login" UI replacement.
- Deliverable: signed requests when keys are set; fallback warning if not.
- Acceptance: verified with live API using user-provided keys.

Milestone 7 — Packaging and verification
- Symbian packaging: .sis build, signing workflow notes.
- Manual test checklist:
  - Search, load, play, pause, seek, resume
  - Offline open subscriptions
  - Error states (no network, invalid key)
- Deliverable: release checklist + build steps.
- Acceptance: build produced on target device or emulator.
