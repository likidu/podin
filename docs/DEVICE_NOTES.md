Symbian Belle Device Notes
==========================

Hardware: Nokia C7 (Belle FP2)

## 2026-02-18 — Artwork Cache & Image Proxy

### Problem
Detail page artwork never displays. List page images (loaded directly via QML
`Image.source`) work fine.

### Root Causes (multiple, layered)

1. **Missing guid/imageUrlHash in detail page params.**
   `SubscriptionsPage.openPodcastDetail()` didn't pass `podcastGuid` or
   `imageUrlHash` to `PodcastDetailPage`. The proxy URL condition failed,
   falling back to the original full-size image URL (3000x3000, 3.5MB).

2. **Wrong file extension from proxy URL.**
   `extensionFromUrl()` parses the URL path for a dot. The proxy URL
   (`/hash/.../feed/.../128`) has no extension, so it defaulted to `.jpg`.
   But the proxy returns PNG. Qt on Symbian can't auto-detect format mismatch
   — file saved as `cover.jpg` containing PNG data fails to decode.
   Fix: read `Content-Type` response header to determine extension.

3. **SSL errors killing downloads silently.**
   `ArtworkCacheManager` used its own plain `QNetworkAccessManager`. QML images
   work because they go through `SslIgnoringNam` (auto-ignores SSL errors via
   `createRequest` override). The cache manager's `onSslErrors` slot fired too
   late. Fix: connect `ignoreSslErrors()` directly on the reply, same pattern
   as `SslIgnoringNam`.

4. **Cleanup loop deleting the temp file before rename.**
   The "remove old cover files" loop matched ALL files starting with `cover`,
   including the `.part` temp file just written. `QFile::rename()` then failed
   because the source was deleted. Fix: skip the temp file in the cleanup loop.

5. **Raw file paths instead of file:// URLs.**
   `artworkCached` signal emitted raw paths (`E:/Podin/.../cover.png`) but QML
   `Image.source` requires `file:///` URLs. Needed `QUrl::fromLocalFile()`.

6. **findCachedFile matching .part files.**
   Leftover `.part` files from failed downloads were returned as valid cache
   hits, preventing re-download. Fix: skip `.part` in `findCachedFile`.

### Key Lessons
- QML `Image.source` loaded via `QDeclarativeNetworkAccessManagerFactory` gets
  SSL error handling for free; C++ `QNetworkAccessManager` instances do not.
  Always connect `ignoreSslErrors()` on replies for Symbian HTTPS.
- Never guess file extension from URL — use `Content-Type` header.
- When cleaning up old files before rename, exclude the source temp file.
- Always emit `file:///` URLs (via `QUrl::fromLocalFile()`) for QML images.


## 2026-02-17 — Audio Seeking — KErrMMAudioDevice (-12014)

### Problem
Writing `position` property on QML Audio element causes KErrMMAudioDevice
(-12014), bricking ALL audio until phone restart. MMF is a shared OS service
with no graceful recovery.

### Key Facts
- Error -12014 is Symbian MMF, not Qt. Corrupts audio device at OS level.
- QML property bindings may trigger writes at unexpected state transitions.
- Even guarding to `playingState`/`pausedState` didn't prevent it.

### Resolution
C++ `AudioEngine` wrapping `QMediaPlayer::setPosition()` with state guards.
Defers seek via `m_pendingSeek` if not ready. Works correctly on device.


## 2026-02-17 — SQLite Persistence on Self-Signed SIS

### Problem
Database falls back to `:memory:` — subscriptions lost on restart.

### Root Causes
1. **Data caging**: `/private/<UID>/` dirs writable but invisible to
   `QDir::exists()`. Code skipped them before testing SQLite.
2. **Driver mismatch**: Test used `QSQLITE`, production used `QSYMSQL`.
3. **Path separators**: Forward slashes failed with QSYMSQL.

### Fix
Skip `exists()`/`mkpath()` for `/private/` paths, go straight to SQLite write
test. Use same driver for test as production. Use `toNativeSeparators()`.

### Key Lesson
On Symbian, data-caged directories are writable but invisible. Never rely on
`QDir::exists()` — go straight to I/O test.
