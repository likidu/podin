MVP Plan - Feasibility Build
============================

Goal
- Prove that a Symbian Belle Qt 4.7+ QML app can:
  - Make signed Podcast Index API requests over TLS 1.2
  - Parse JSON and bind models to QML
  - Stream and play episode audio

Non-goals (for MVP)
- Subscriptions, downloads, offline mode, settings UI, discovery, caching, polish.

Step 1 - API client smoke test
- Implement signing helper (HMAC SHA1) and request wrapper.
- Use a fixed query term (hardcoded or config) to call:
  - GET /search/byterm?q=<term>&max=10
- Parse response into a minimal Podcast list model: feedId, title, image.
- Acceptance: list renders in QML with real API data.

Step 2 - Episode fetch wiring
- On podcast selection, call:
  - GET /episodes/byfeedid?id=<feedId>&max=10
- Parse response into minimal Episode list model:
  - title, enclosureUrl, duration, datePublished.
- Acceptance: episode list renders and updates on selection.

Step 3 - Playback proof
- On episode tap, pass enclosureUrl to QMediaPlayer (or Symbian backend).
- Provide play/pause and a basic progress display.
- Acceptance: audio plays, pause/resume works, and time updates in UI.

Step 4 - Minimal error handling
- Show a simple error message on non-200 responses.
- Disable play if enclosureUrl is missing.
- Acceptance: app stays responsive on bad network or empty results.

Deliverable
- A single-screen or two-screen MVP app that can search, list episodes, and play audio.
- Runs on device or emulator using real API keys.
