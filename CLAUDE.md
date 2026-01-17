# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Podin** (Podcast Index) is an offline-first podcast client for Symbian Belle, designed for digital detox. The app prioritizes intentional listening over constant connectivity.

**Goal:** Offline-first PodcastIndex client for digital detox

### Non-Goals

- No streaming (HLS/DASH manifests)
- No push notifications
- No account sync / cloud features
- No social features
- No background refresh outside scheduled times

## Primary User Flows

1. **Add Podcasts** (limit: 3 subscriptions)
   - Search PodcastIndex and subscribe, OR
   - Import by feed URL or podcast ID

2. **Morning Download** (scheduled sync)
   - At a fixed time (e.g., 06:00), app enables Wi-Fi
   - Downloads newest 1-3 episodes for each subscribed podcast
   - Disables Wi-Fi when complete

3. **Offline Playback**
   - Library shows only downloaded episodes
   - Playback works exclusively from local files
   - No network access during listening

## Detox Rules

These rules are **explicit and enforced**:

1. **Scheduled sync only** - Network access occurs only at user-configured time(s)
2. **No background refresh** - App never polls for updates outside scheduled windows
3. **No streaming** - Episodes must be fully downloaded before playback
4. **Optional "hard mode"** - Hide the manual "refresh" button entirely

## Acceptance Criteria

| Scenario | Expected Behavior |
|----------|-------------------|
| Scheduled sync at 06:00 | App enables Wi-Fi, downloads newest 1-3 episodes per podcast (3 podcasts max), then disables Wi-Fi |
| Playback attempt | Works only with local files; no network fallback |
| Episode format selection | Prefers progressive MP3/M4A over HLS/DASH manifests |
| Manual refresh (normal mode) | Button visible, triggers immediate sync |
| Manual refresh (hard mode) | Button hidden; sync only at scheduled time |

## Technical Constraints

- **Platform:** Symbian Belle, Qt 4.7.4+, QML 1.1, C++03 (no C++11)
- **Media:** QMediaPlayer with local files only; progressive HTTP download (not streaming)
- **Networking:** TLS v1.2 via patched Qt stack
- **Background execution:** Alarm Server / autostart / headless helper for scheduled downloads
- **Capabilities:** Networking, read/write storage, device data (signed)

## Build Commands

### Building for Qt Simulator

Use PowerShell scripts located in `scripts/`:

```powershell
# Default: build and use the simulator runtime
pwsh scripts/build-simulator.ps1 -Config Debug

# Clean then build
pwsh scripts/build-simulator.ps1 -Config Debug -Clean

# Stage patched DLLs from deps/win32 instead of using the runtime
pwsh scripts/build-simulator.ps1 -Config Debug -UseDepDlls

# Release build
pwsh scripts/build-simulator.ps1 -Config Release
```

Output lands in `build-simulator/debug/` (or `release/` when `-Config Release`).

### Running the Application

- **Simulator runtime (default):** `pwsh -File build-simulator\debug\Podin.run.ps1`
- **Staged DLL mode:** `build-simulator\debug\Podin.exe` (DLLs copied next to executable)
- **Qt Creator:** Open `Podin.pro`, select Simulator kit, and launch

### Running Tests

```powershell
# Run PlayerPage tests
pwsh scripts/run-playerpage-tests.ps1
```

Individual tests are located in `tests/` directory:
- `tests/tlscheck/` - TLS check test (console app)
- `tests/playerpage/` - PlayerPage QML component test

### Inspecting Runtime Binaries

```powershell
# Check build-simulator\debug by default
pwsh scripts/inspect-sim-runtime.ps1 -Config Debug

# Focus on QtNetwork + OpenSSL
pwsh scripts/inspect-sim-runtime.ps1 -Config Debug -OnlyNetSsl

# Specify custom directory
pwsh scripts/inspect-sim-runtime.ps1 -Config Release -Dir 'build-simulator\release'
```

## Architecture

### Build System

- **qmake project file:** `Podin.pro` defines build configuration
- **Qt 4.x modules:** Uses core, gui, network, declarative
- **Static qjson library:** Embedded JSON parser/serializer in `lib/qjson/`, included via `qjson.pri`
- **Build artifacts:** Organized in subdirectories (obj, moc, rcc, ui) under build output

### Runtime Library Management

The application handles Qt Simulator runtime detection and PATH configuration automatically:

- **Simulator detection:** `main.cpp` contains logic to find Qt Simulator installation (checks `QTSIMULATOR_ROOT`, common paths like `C:/Symbian/QtSDK/Simulator`, and walks up from app directory)
- **PATH manipulation:** Prepends Qt and QtMobility bin/lib directories to PATH at runtime via `ensureRuntimeLibraries()`
- **Plugin/import paths:** Dynamically builds and sets QML import paths and Qt plugin paths pointing to simulator install
- **Two runtime modes:**
  - Default: Uses simulator's Qt runtime, generates `Podin.run.ps1` launcher that sets up PATH
  - `-UseDepDlls`: Copies patched Qt 4.7.4 + OpenSSL 1.0.2u DLLs from `deps/win32/qt4-openssl/{debug,release}/` next to executable

### Core Components (Planned)

- **PodcastIndex API Client:** Search podcasts, fetch feed metadata, enumerate episodes
- **Download Manager:** Queue and download episodes as progressive MP3/M4A files
- **Episode Storage:** Local SQLite database for subscriptions and episode metadata
- **Scheduler:** Alarm Server integration for scheduled sync windows
- **Playback Engine:** QMediaPlayer wrapper for local file playback
- **Wi-Fi Controller:** Enable/disable wireless during sync windows

### Current C++ Backend

- **`src/main.cpp`:** Application entry point, QDeclarativeView setup, runtime library path management
- **`src/TlsChecker.{h,cpp}`:** QObject-based class for TLS connectivity testing
- **`src/ApiConfig.h`:** API configuration namespace with endpoint URLs and headers

### QML UI

- **`qml/AppWindow.qml`:** Root window/page stack container
- **`qml/MainPage.qml`:** Main screen with test buttons and status display
- **`qml/PlayerPage.qml`:** Audio playback test page using QtMultimediaKit
- **Resource collection:** QML files bundled via `qml/qml.qrc`

### Dependencies

- **qjson library:** Statically linked JSON parser/serializer from `lib/qjson/`
  - Provides `QJson::Parser` and `QJson::Serializer` classes
  - Works with `QVariant`, `QVariantMap`, `QVariantList` for JSON data structures

### Qt 4.x Compatibility Notes

- Uses Qt 4.7.4 APIs throughout
- Conditional compilation for Qt 4.8+ SSL version APIs (`#if (QT_VERSION >= 0x040800)`)
- QML 1.1 syntax with Symbian components (`import com.nokia.symbian 1.1`)
- Manual string joining function (`joinStrings`) since Qt 4.x `QStringList::join()` has different API

## File Organization

```
Podin.pro              # qmake project file
src/                   # C++ source code
  main.cpp             # Application entry, runtime setup
  TlsChecker.{h,cpp}   # TLS test logic (temporary/diagnostic)
  ApiConfig.h          # API configuration (header-only)
qml/                   # QML UI files and resources
  AppWindow.qml        # Root window
  MainPage.qml         # Main page
  PlayerPage.qml       # Audio player page
  qml.qrc              # Resource file
lib/qjson/             # Embedded JSON library
scripts/               # PowerShell build/test scripts
tests/                 # Test applications
  tlscheck/            # Standalone TLS test
  playerpage/          # PlayerPage component test
deps/win32/qt4-openssl/ # Optional patched Qt + OpenSSL DLLs
build-simulator/       # Build output (debug/release)
```

## Development Notes

- Episode downloads must complete fully before appearing in library (no partial/streaming)
- Prefer MP3/M4A enclosures; skip episodes with only HLS/DASH manifests
- Wi-Fi control is platform-specific; abstract behind interface for simulator testing
- Alarm Server integration requires appropriate Symbian capabilities
- All network operations use timeouts to avoid hanging on poor connectivity
- PATH and plugin path manipulation in `main.cpp` is critical for simulator operation
