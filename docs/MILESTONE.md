Each milestone should end with something you can run on-device.

## Milestone 0: Hello device + plumbing

- QML shell: 3 tabs (Library / Downloads / Settings)
- C++ bridge exposed to QML (one test method call)
- Local SQLite opens, migrations run

Done when: app installs and launches reliably.

## Milestone 1: PodcastIndex client (fixture-first)

- Implement API client against fixtures/
- Search podcasts, display results, subscribe
- Store podcast metadata + image URL

Done when: you can subscribe to 3 podcasts using fixture mode.

## Milestone 2: Episodes list + progressive media filter

- Fetch episodes for a podcast
- Apply your “progressive-only gate”
- Display episode list with download buttons

Done when: “bad” media URLs are filtered out deterministically.

## Milestone 3: Download manager (robust)

- Queue downloads, resume, progress UI
- Save to disk with safe filenames
- Offline library view

Done when: episodes download end-to-end and persist across app restart.

## Milestone 4: Local playback + vinyl UI

- QMediaPlayer plays local file paths
- Vinyl animation + play/pause/seek
- “Now Playing” mini bar

Done when: you can play a downloaded episode with correct state visuals.

## Milestone 5: Morning Download scheduler

- Settings: time picker, choose 3 podcasts (or “use current top 3”)
- At trigger time: connect Wi-Fi, download latest episodes, disconnect
- Logging screen (“Last run: success/failure, errors”)

Done when: the scheduled run works at least once on real hardware.

## Milestone 6: Detox hardening

- Remove/disable manual refresh (optional)
- No notifications, no background polling
- “Offline-only mode” toggle for leaving home

Done when: the app behaves like a detox tool, not a feed reader.

## Milestone 7: Polish + release

- Better errors, retry/backoff
- Artwork caching, list performance
- SIS signing + release checklist

Done when: you can daily-drive it.
