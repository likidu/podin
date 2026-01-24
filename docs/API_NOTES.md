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
  - podcastGuid (guid)
  - title
  - description
  - image or artwork
  - url (feed URL)

2) Podcast details by feed id
- GET /podcasts/byfeedid?id=<feedId>
- Required fields (detail view):
  - id (feedId)
  - podcastGuid (guid)
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
  - enclosureType (mime type, if present)
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
 - enclosureType -> media label (mp3/m4a)

Screen mapping (current MVP + planned)
- Main/Search screen
  - Endpoint: /search/byterm
  - UI fields:
    - feeds[].id -> feedId (used to fetch episodes)
    - feeds[].title -> list title
    - feeds[].description -> list subtitle
    - feeds[].image/artwork -> list image
- Podcast detail screen (planned)
  - Endpoint: /podcasts/byfeedid or /podcasts/byguid
  - UI fields:
    - feed.id -> feedId (for subscribe + episode fetch)
    - feed.title -> title
    - feed.description -> long description
    - feed.image/artwork -> cover
    - feed.author -> byline (optional)
    - feed.url -> feed URL (optional)
- Episodes screen (current)
  - Endpoint: /episodes/byfeedid
  - UI fields:
    - items[].title -> episode title
    - items[].datePublished -> date label
    - items[].duration -> duration label
    - items[].enclosureUrl -> playable URL
    - items[].enclosureType -> media label
    - items[].image/feedImage -> (optional) artwork
- Player panel (current, embedded in EpisodesPage)
  - Uses: title + enclosureUrl + duration + enclosureType
- Optional discovery screen (later)
  - Endpoints: /recent/episodes, /trending
  - Same episode fields as above.

Normalized fields exposed to QML (current code)
- Podcast list items: feedId, title, description, image
- Podcast list items: guid (when available)
- Episode list items: id, title, description, datePublished, duration, enclosureUrl, enclosureType, image

Error handling
- Non-200 responses: show error and keep cached data if present.
- Empty arrays: show "No results".
- Missing enclosureUrl: disable play button for that episode.

Rate limits
- Use basic retries for transient errors only.
- Avoid aggressive polling; refresh on explicit user action.
