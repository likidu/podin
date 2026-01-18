Podcast Index API Notes
=======================

Scope: minimal endpoints for a playback-first Symbian client. No social, no sync.

Base
- Base URL: https://api.podcastindex.org/api/1.0
- TLS: v1.2 (already handled by scaffold)

Auth (when keys are set)
- Required headers:
  - X-Auth-Key: <api_key>
  - X-Auth-Date: <unix_timestamp>
  - Authorization: <sha1_hmac>
- HMAC input: api_key + api_secret + unix_timestamp
- Content type: application/json

Endpoints (initial)
1) Search by term
- GET /search/byterm?q=<term>&max=<n>
- Required fields (list view):
  - id (feedId)
  - title
  - description
  - image or artwork
  - url (feed URL)

2) Podcast details by feed id
- GET /podcasts/byfeedid?id=<feedId>
- Required fields (detail view):
  - id (feedId)
  - title
  - description
  - image or artwork
  - author
  - url (feed URL)

3) Episodes by feed id
- GET /episodes/byfeedid?id=<feedId>&max=<n>
- Required fields (episode list + player):
  - id or guid
  - title
  - description
  - datePublished (unix timestamp)
  - duration (seconds)
  - enclosureUrl (audio URL)
  - image or feedImage

Optional discovery (later)
- GET /recent/episodes?max=<n>
- GET /trending?max=<n>
- Same episode fields as above.

Response structure (common)
- Top-level usually contains: status, count, description
- Arrays:
  - "feeds" for podcast lists
  - "items" for episode lists

Field mapping (UI)
- title -> list and detail titles
- description -> detail text (truncate in lists)
- image/artwork -> cover image
- datePublished -> formatted date
- duration -> mm:ss
- enclosureUrl -> player source

Error handling
- Non-200 responses: show error and keep cached data if present.
- Empty arrays: show "No results".
- Missing enclosureUrl: disable play button for that episode.

Rate limits
- Use basic retries for transient errors only.
- Avoid aggressive polling; refresh on explicit user action.
