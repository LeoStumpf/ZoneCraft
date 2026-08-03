# ZoneCraft — Privacy Policy

_Last updated: 2026-08-02_

ZoneCraft is an offline-first map tool. It has **no account system** and does **not** sell,
rent, or share your personal data. This policy explains the limited data the app handles.

## Data stored on your device

Everything you create — layers, circles, planes, subspaces, freehand lines/areas, height
regions, imported points of interest, transit stations and administrative areas, settings,
and the cached map tiles — is stored **only on your device** in a local database. It is never
uploaded to us, and we have no server that receives it. Uninstalling the app, or using
**Settings → Clear all data**, removes it. (Cached map tiles are not user data and survive
that button; they have their own **Clear cached map tiles**.)

## Location

If you tap **"Locate me"**, the app requests **foreground (precise/approximate) location** to
centre the map on your position. Location is:

- requested **only** when you use that feature (never at launch, never in the background);
- used **only** on-device to move the map;
- **not** stored, logged, or transmitted to us or any third party.

You can decline the permission and use every other feature normally.

## Network requests to third parties

To display the map and to import data you ask for, the app fetches directly from third-party
services. There is no ZoneCraft server in between. Your device's IP address — and whatever the
request itself contains (the map area you are viewing, the coordinates you probe, the text you
search for) — is necessarily visible to the service being asked:

- **OpenStreetMap tile servers** (`tile.openstreetmap.org`) — the base map. Contacted only
  for the tiles you are actually looking at; tiles you have already viewed are re-served from
  the device. See the [OSMF Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy).
- **Overpass API** — used for the **points of interest**, **public-transport station** and
  **administrative border** imports. Contacted only when you start an import, never in the
  background. The app tries `overpass-api.de`, `overpass.kumi.systems` and
  `overpass.private.coffee` in turn until one answers, and remembers which one did.
- **Nominatim** (`nominatim.openstreetmap.org`) — OpenStreetMap's geocoder, used by
  **"Import a feature by name"**. It receives the search text you submit. Contacted only when
  you run a search — never as you type — and repeated searches are answered from memory
  without contacting it again.
- **AWS Terrain Tiles** (`s3.amazonaws.com/elevation-tiles-prod`) — public elevation data,
  used by **height layers**, the **"Measure elevation"** probe, and the elevation readout
  after **"Locate me"**. It receives the tile covering the point being measured.

The app sends no identifying information with these requests beyond what any HTTP client sends
(IP address, and a descriptive `User-Agent` naming the app). There is no advertising ID, no
device identifier, and no analytics.

## Crash diagnostics (Sentry)

To find and fix crashes on the variety of devices the app runs on, ZoneCraft sends **crash and
error reports** to [Sentry](https://sentry.io/) (a third-party error-monitoring service). These
reports contain technical diagnostics — error type, stack trace, app version, and device/OS
model — and **do not include** your layers, locations, or any content you create. Performance
tracing is switched off; only crashes and errors are sent. See
[Sentry's Privacy Policy](https://sentry.io/privacy/).

## Children

The app is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the "Last updated" date above will change accordingly.

## Contact

Questions: open an issue at <https://github.com/LeoStumpf/zonecraft> or email
leo.m.stumpf@gmail.com.
