Podcast Index Client for Symbian Belle (Qt 4.7+ + QML)
======================================================

Milestone 0 — Scope, constraints, and API mapping (done)
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
Status notes:
- Implemented: /search/byterm and /episodes/byfeedid are wired in C++ client.
- Implemented: /podcasts/byfeedid wired for detail screen.
- Implemented: /podcasts/byguid fallback when feedId is missing.
- Pending: /recent/episodes, /trending.
- Done: spec doc mapping screens to API fields (docs/API_NOTES.md).

Milestone 1 — App architecture and data flow (mostly done)
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
Status notes:
- Done: C++ client with QNetworkAccessManager + QJson parsing + timeouts + errors.
- Done: search() and fetchEpisodes() exposed to QML.
- Done: auth header signing (HMAC SHA1 style) + env/default API key/secret.
- Pending: storage layer.
- Pending: retries/backoff.

Milestone 2 — Minimal UI shell in QML (partial)
- QML screens (simple, phone-friendly):
  1) Search screen (text input + results list)
  2) Podcast detail (art, title, description, subscribe)
  3) Episode list (title, date, duration)
  4) Player (title, progress, play/pause, seek)
- Use standard Symbian components where possible; keep layout light.
- Add loading and error states (empty list, API error).
- Deliverable: QML screens wired to placeholder models.
- Acceptance: navigation flow works with mock data; no crashes on back/forward.
Status notes:
- Done: search screen + results list.
- Done: episodes list + embedded player panel.
- Done: loading/error/empty states.
- Done: dedicated podcast detail screen (search -> detail -> episodes).
- Done: dedicated player screen wired from episodes page.
- Done: seek UI/control (player panel + player screen).

Milestone 3 — Core data + playback (partial)
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
Status notes:
- Done: live API fetch for search + episodes.
- Done: playback via QtMultimediaKit Audio (AudioFacade wrapper).
- Done: position/duration reflected in UI.
- Done: podcast detail API screen uses /podcasts/byfeedid.
- Done: seek slider and buffer/status text in player panel.
- Done: forward/back (seek) via C++ AudioEngine (src/AudioEngine.h/.cpp). Replaced QML
  AudioFacade with QMediaPlayer wrapper using setPosition() with state guards and pending-seek
  mechanism. Writing position from QML caused KErrMMAudioDevice (-12014); C++ avoids this.
  See docs/DEVICE_NOTES.md for full details.

Milestone 4 — Local state and offline basics (in progress)
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
Status notes:
- Done: SQLite storage manager + schema creation.
- Done: SQLite persistence on self-signed SIS — fixed dbPath() to handle Symbian data caging:
  skip QDir::exists()/mkpath() for /private/ paths, use same SQL driver (QSYMSQL) for test as
  initDb(), use QDir::toNativeSeparators(). Database now persists in app's private directory.
  See docs/DEVICE_NOTES.md for details.
- Done: subscriptions page + toolbar entry.
- Done: subscribe/unsubscribe from podcast detail page.
- In progress: resume playback position stored per episode.

Milestone 5 — Robustness and UX polish (partial)
- Error handling: network failures, missing audio URLs, rate limits.
- Offline behavior: show cached subscriptions/episodes.
- Performance: image caching (local file cache), lazy loading for lists.
- Bandwidth controls: "stream only" vs "download on tap".
- Deliverable: smoother user experience without adding extra features.
- Acceptance: app does not hang on bad network; graceful fallback UI.
Status notes:
- Done (extra): TLS 1.2 check UI and runtime diagnostics (TlsChecker, stripped of old
  Xiaoyuzhoufm JSON test code).
- Done: image proxy integration (https://podcastimage.liya.design/). List pages request /32,
  detail page requests /128. ArtworkCacheManager downloads and caches to E:/Podin/ with
  Content-Type-based extension detection, SSL error handling, and file:// URL emission.
  Artwork loading enabled by default. See docs/DEVICE_NOTES.md for bug details.
- Done: centralized app paths in src/AppConfig.h (kMemoryCardBase, kPhoneBase, kLogsSubdir).
  Removed old ApiConfig.h (Xiaoyuzhoufm experiment). All paths use AppConfig constants.
- Done: sleep timer (15/30/60/90/120 min presets) with device power-off via HAL.
  Timer counts down while playing, pauses when playback pauses.
  TODO: when playlist feature is added, sleep timer should continue across episodes.
- Pending: caching/offline behavior, bandwidth controls.
- Pending: use custom SVG as toolbar icon.
- Next steps (memory): consider replacing page transitions to reduce stack retention;
  consider lowering episode fetch count on low-RAM devices.

Milestone 6 — Authentication and future "login" hook (partial)
- Add a settings screen for API key + secret (optional now, required later).
- Implement signing helper (HMAC SHA1 per Podcast Index spec):
  - X-Auth-Key, X-Auth-Date, Authorization
- Keep it modular to allow later "login" UI replacement.
- Deliverable: signed requests when keys are set; fallback warning if not.
- Acceptance: verified with live API using user-provided keys.
Status notes:
- Done: auth headers and env/default key/secret support in C++ client.
- Pending: settings UI for user-provided keys.

Milestone 7 — Packaging and verification (partial)
- Symbian packaging: .sis build, signing workflow notes.
- Manual test checklist:
  - Search, load, play, pause, resume
  - Offline open subscriptions
  - Error states (no network, invalid Podcast Index key)
- Deliverable: release checklist + build steps.
- Acceptance: build produced on target device or emulator.
Status notes:
- Done: simulator build scripts and README build/run steps.
- Done: Symbian .sis packaging notes + checklist (docs/SYMBIAN_PACKAGING.md).
- Pending: device verification on Nokia C7 (Belle FP2).
