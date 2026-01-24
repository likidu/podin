# Storage Schema (Milestone 4 Draft)

This document proposes the SQLite schema (via QtSql) and the small QSettings keys
to support subscriptions, episode history, and resume playback.

## SQLite (primary app data)

Database file: `podin.db` (location chosen by the app, e.g. app data dir).

### Table: `subscriptions`

Purpose: persisted subscriptions list.

```sql
CREATE TABLE IF NOT EXISTS subscriptions (
  feed_id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  image TEXT,
  last_updated INTEGER
);
```

Notes:
- `feed_id` is the PodcastIndex feed id.
- `last_updated` is a Unix timestamp (seconds) for metadata refresh.

### Table: `episodes`

Purpose: episode metadata + playback state (per episode).

```sql
CREATE TABLE IF NOT EXISTS episodes (
  episode_id TEXT PRIMARY KEY,
  feed_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER,
  played_position_ms INTEGER DEFAULT 0,
  last_played_at INTEGER,
  published_at INTEGER,
  enclosure_type TEXT,
  play_state INTEGER DEFAULT 0,
  image TEXT,
  FOREIGN KEY(feed_id) REFERENCES subscriptions(feed_id)
);
```

Suggested indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_episodes_feed_id ON episodes(feed_id);
CREATE INDEX IF NOT EXISTS idx_episodes_last_played ON episodes(last_played_at);
```

Notes:
- `episode_id` can be `guid` or `id` from the API; store as TEXT to avoid collisions.
- `played_position_ms` stores resume position.
- Downloads are deferred for now; no local file path is stored.
- `play_state` stores last known playback state (0=stopped, 1=playing, 2=paused).

### Optional table: `recent_activity`

Purpose: fast list of recently played or recently fetched episodes (if needed).

```sql
CREATE TABLE IF NOT EXISTS recent_activity (
  episode_id TEXT PRIMARY KEY,
  last_seen_at INTEGER
);
```

Note: This can be derived from `episodes.last_played_at`, so the table is optional.

## QSettings (small app/UI preferences)

Purpose: small, non-relational state. Stored via `QSettings`.

Suggested keys:
- `ui/last_search_term` (string)
- `ui/last_feed_id` (int)
- `ui/last_episode_id` (string)
- `ui/stream_only` (bool)
- `player/volume` (float 0.0–1.0)
- `player/muted` (bool)
- `player/last_position_ms` (int) (optional; prefer per-episode in SQLite)

## Mapping to Milestone 4 Requirements

- Subscriptions: `subscriptions` table.
- Episode table: `episodes` table.
- Resume playback: `episodes.played_position_ms` + `episodes.last_played_at`.
- Recent list: `episodes.last_played_at` (or `recent_activity` if needed).
- Downloads: `episodes.local_path`.
