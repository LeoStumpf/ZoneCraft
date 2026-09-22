# Data sources and policies

ZoneCraft has no server of its own. Everything it shows is fetched on demand from services
other people pay to run, each with a usage policy the app is written to honour. This page is
for people forking the app, and for the operators of those services.

## The services

| Service | Used for | Where |
|---|---|---|
| **OpenStreetMap tiles** | The base map | `tile.openstreetmap.org` by default, run on donations; or a provider of your own (`TILE_URL`, or Settings → Data sources) |
| **Overpass** | Places, station and border imports | `overpass-api.de`, then `overpass.kumi.systems`, then `overpass.private.coffee` — three community instances tried in turn; a configured server is tried first |
| **Nominatim** | *Go to place* and *Import map feature by name* | `nominatim.openstreetmap.org` |
| **AWS Terrain Tiles** | Ground-height layers, *Measure elevation*, the height under *Locate me* | `s3.amazonaws.com/elevation-tiles-prod/terrarium/` — SRTM, 3DEP and GMTED2010 courtesy of the U.S. Geological Survey; ETOPO1 courtesy of NOAA |
| **OpenStreetMap Notes API** | *Tell OpenStreetMap* — the one thing the app ever writes | `api.openstreetmap.org`; `OSM_API_URL` at build time |

## What the app asks of them

**Only when you ask.** No timer, no background fetch, no request on a map move except for
the tiles on screen. An import runs once and is stored for good; it never refreshes.

**One request per second, at most.** Every call to a donated service goes through a pacer
(`lib/data/request_pacer.dart`: 1.1 s for Nominatim, whose policy's ceiling is 1 req/s; 1 s
for Overpass; 1 s for the Notes API). They are *pacers*, not debouncers — these are explicit
user actions, so a late request is right and a dropped one would look like a dead button.
Nominatim results additionally go through a client-side cache, because its policy requires
one and blocks clients that repeat identical queries. There is **deliberately no
search-as-you-type**: the policy forbids it.

**The map is never downloaded ahead of you.** OpenStreetMap's
[tile usage policy](https://operations.osmfoundation.org/policies/tiles/) defines bulk
downloading as *any pre-emptive fetching of tiles other than those a user is actively
viewing*, so the one-tile-ring viewport prefetch and the *Download this area* button are
**off by default** (`lib/data/tile_source.dart`; `test/tile_source_test.dart` guards it).
Caching what *was* displayed is a different thing — the policy requires that, and it is
always on, capped at 200 MB with LRU eviction.

**Redirecting the tiles does not grant prefetching.** `TILE_URL` and `TILE_ALLOWS_PREFETCH`
are separate build-time defines, because leaving OpenStreetMap says nothing about the next
provider's terms: MapTiler forbids "batch or excessive bulk download of map tiles" on every
plan, Thunderforest forbids "pre-downloading, pre-caching or anything similar" below its
Small Business plan. The build script refuses the flag without a URL. A URL typed into
**Settings → Data sources** at runtime forces prefetch *off* whatever the build said — a
typed-in address asserts nothing about anyone's terms.

**The app says who it is.** One `User-Agent` on every request, built from the version:

```
ZoneCraft/1.4.0 (+https://github.com/LeoStumpf/ZoneCraft)
```

Every policy the app is subject to requires a string naming *this* app and forbids a library
default, and all the operators block by exactly that string. `test/app_info_test.dart` pins
that it carries the current version.

**Every call is timed out** (15 s per tile, 15 s per terrain tile with a 90 s budget on a
whole height generation, per-request budgets on Overpass, a time limit on the position
fix), and a response over a size cap is refused rather than swallowed — a border import
can otherwise pull tens of megabytes off a donated server.

**Overpass failover is for transient failures only.** A `429`, `500`, `502`, `503` or `504`
moves to the next instance; a query the server rejected outright is not retried anywhere. The instance that last
answered is remembered and tried first next time.

**One note per press.** *Tell OpenStreetMap* files an anonymous note through the Notes API,
which OpenStreetMap's developer guidance sanctions for third-party apps. It is **never
retried and never fails over** (a POST that timed out may well have been applied, and there
is only one OpenStreetMap), the outbox has **no timer, no flush-on-reconnect, no
send-at-launch**, the text is a draft the user edits (no automated notes), the warning that
it is for map data and not app feedback is shown every time, and the app holds itself to
osm.org's own anonymous limits — warn at 5 notes a day, withdraw Send at 10. See
[Correcting a Place](Correcting-a-Place.md).

**Attribution is the app's own chrome.** The credit is a permanently visible pill on the
map — not `flutter_map`'s collapsed (i) — because ODbL attribution is a licence term rather
than a courtesy. It prints the tile source's own line verbatim, and its tap lists
OpenStreetMap plus the terrain sources Tilezen's terms require be named.

## When a server says no

A server that answers and refuses — a spent quota, a refused key, a blocked client — looks
exactly like a broken app. After three consecutive refusals the app raises one banner with a
**Why?** that says the reassuring half first (your data is untouched) and names the likely
cause: for the community OSM servers, that they are donated and may block; for a keyed
provider, an allowance that resets. Not reaching the server at all raises nothing — offline
is the normal state the cache exists for.

## Running your own

**Settings → Data sources** points the tiles, Overpass and Nominatim at servers of your own
without rebuilding (`lib/data/service_overrides.dart` is the one definition of the three).
Nominatim's policy asks that apps be able to switch service at its request; Overpass's own
docs say an app leaning on the public instances is what running your own is for — and of
the three, **an Overpass instance is the one that genuinely helps**. The public instances
stay as a fallback behind an override, so a typo costs a slow import, not a dead app.

`OSM_API_URL` is deliberately *not* a runtime setting: the OSM database is not a service you
swap, and a typed-in URL would send somebody's contribution to a stranger's server.

## If you operate one of these services

If ZoneCraft is causing you trouble, **please write rather than block** — a block lands on
the User-Agent, which is every install at once, and an email gets a fast answer. The app's
own **Servers and limits** screen (About → Servers and limits) prints the exact User-Agent
your logs will contain beside these, copyable:

- Email: <leo.m.stumpf@gmail.com>
- Issues: <https://github.com/LeoStumpf/ZoneCraft/issues>

## Privacy

Every request carries the app's name and version and nothing that identifies the user; the
app has no analytics, no crash reporting and no advertising id. The full statement is
[`PRIVACY.md`](https://github.com/LeoStumpf/ZoneCraft/blob/main/PRIVACY.md); the third-party
notices are
[`THIRD_PARTY_NOTICES.md`](https://github.com/LeoStumpf/ZoneCraft/blob/main/THIRD_PARTY_NOTICES.md).
