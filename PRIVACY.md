# ZoneCraft — Privacy Policy

_Last updated: 2026-08-03_

ZoneCraft is an offline-first map tool. It has **no account system**, shows **no advertising**,
and does **not** sell, rent or share your personal data. There is no ZoneCraft server: nothing
you create is uploaded anywhere.

This policy explains the limited data the app handles, and is written to be read — not to be
skimmed past.

**Who is responsible.** ZoneCraft is published by Leo Stumpf, an individual developer
(Munich, Germany). Contact: <leo.m.stumpf@gmail.com>.

## Summary

| | |
|---|---|
| Account required | No |
| Data collected about you | None, except crash diagnostics (below) |
| Data sold or shared for advertising | Never |
| Where your content lives | On your device only |
| Advertising ID / device identifier | Not used |
| Analytics or usage tracking | None |

## Data stored on your device

Everything you create — layers, circles, planes, subspaces, freehand lines and areas, height
regions, imported points of interest, transit stations and administrative areas, your settings
and your last map position — is stored **only on your device** in a local database. It is never
uploaded to us, and we have no server that could receive it.

Cached map tiles are stored alongside it. These are not personal data — they are pictures of
the map — but they do imply which areas you have looked at, so they are worth naming.

## Location

If you tap **"Locate me"**, the app requests **foreground (precise or approximate) location** to
centre the map on your position and read the terrain elevation there. Location is:

- requested **only** when you use that feature — never at launch, never in the background;
- used **only** on your device, to move the map;
- **not** stored, logged, or transmitted to us or to any third party.

You can decline the permission and use every other feature normally.

The one indirect exposure worth stating plainly: after "Locate me", the app fetches the
elevation tile covering your position from the public elevation dataset listed below. That
request reveals an area of roughly a few kilometres across, not your exact position, and it is
not linked to any identifier.

## Network requests to third parties

To display the map and to run the imports you ask for, the app fetches directly from
third-party services. There is no ZoneCraft server in between, which means your device's IP
address — and whatever the request itself contains (the map area you are viewing, the
coordinates you probe, the text you search for) — is necessarily visible to the service being
asked. Each of these is an independent data controller under its own policy:

- **OpenStreetMap tile servers** (`tile.openstreetmap.org`) — the base map. Contacted only for
  the tiles you are actually looking at; tiles already viewed are re-served from your device.
  See the [OSMF Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy).
- **Overpass API** — the **points of interest**, **public-transport station** and
  **administrative border** imports. Contacted only when you start an import, never on a timer
  and never as the map moves. The app tries `overpass-api.de`, `overpass.kumi.systems` and
  `overpass.private.coffee` in turn until one answers, and remembers which one did.
- **Nominatim** (`nominatim.openstreetmap.org`) — OpenStreetMap's geocoder, used by **"Import a
  feature by name"**. It receives the search text you submit. Contacted only when you run a
  search — never as you type — and a repeated search is answered from memory without contacting
  it again.
- **AWS Terrain Tiles** (`s3.amazonaws.com/elevation-tiles-prod`) — public elevation data, used
  by **height layers**, the **"Measure elevation"** probe, and the elevation readout after
  **"Locate me"**. It receives the tile covering the point being measured.

The app sends nothing identifying with these requests beyond what any HTTP client sends: your
IP address, and a `User-Agent` naming the application. No advertising ID, no device identifier,
no cookies, no analytics.

## Crash diagnostics (Sentry)

Store releases send **crash and error reports** to [Sentry](https://sentry.io/), a third-party
error-monitoring service, so that faults on the wide range of Android devices out there can be
found and fixed.

These reports contain technical diagnostics only: the error type, a stack trace, the app
version, and the device and OS model. They **do not include** your layers, your objects, your
location, your searches, or any other content you create. Performance tracing is switched off —
only crashes and errors are sent. Sentry acts as a data processor on our behalf; see
[Sentry's Privacy Policy](https://sentry.io/privacy/).

Builds compiled without a Sentry key — including every build you make yourself from source —
send nothing at all.

## Exporting and sharing your data

**Export** writes your layers to a GeoJSON or KML file and hands it to Android's share sheet.
Where that file then goes is entirely your choice: nothing is transmitted to us, and the app has
no visibility into what you do with it. The file is written to the app's temporary directory and
is removed by the system in the normal course of clearing app caches.

## Data retention and deletion

Your content is kept until you delete it. There is nothing to request from us, because we hold
nothing:

- **Settings → Clear all data** deletes every layer and object and resets settings.
- **Settings → Clear cached map tiles** empties the tile cache (kept separate, because it is
  cache rather than your data).
- **Uninstalling the app** removes everything, both together.

Crash reports held by Sentry are retained according to Sentry's own retention schedule (90 days
by default) and contain no information identifying you.

## Your rights

Because the app collects no personal data about you and holds nothing on a server, there is in
practice nothing for us to disclose, correct or erase — your content is already exclusively in
your hands. If you are in the EU/EEA or UK and believe otherwise, or you want the crash
diagnostics associated with your device removed, email <leo.m.stumpf@gmail.com> and it will be
handled.

Where any processing does occur, the legal basis is legitimate interest (Art. 6(1)(f) GDPR) in
delivering a working, debuggable application; for location, it is your consent, given by
granting the permission and revocable at any time in Android's settings.

## Children

The app is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the "Last updated" date above changes with it. Material changes will be
noted in the app's release notes.

## Contact

Questions, or anything that looks wrong here: open an issue at
<https://github.com/LeoStumpf/ZoneCraft> or email <leo.m.stumpf@gmail.com>.
