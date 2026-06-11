# ZoneCraft — Privacy Policy

_Last updated: 2026-06-11_

ZoneCraft is an offline-first map tool. It has **no account system** and does **not** sell,
rent, or share your personal data. This policy explains the limited data the app handles.

## Data stored on your device

Everything you create — layers, circles, planes, subspaces, freehand lines/areas, settings,
and the cached map tiles — is stored **only on your device** in a local database. It is never
uploaded to us, and we have no server that receives it. Uninstalling the app, or using
**Settings → Clear all data**, removes it.

## Location

If you tap **"Locate me"**, the app requests **foreground (precise/approximate) location** to
centre the map on your position. Location is:

- requested **only** when you use that feature (never at launch, never in the background);
- used **only** on-device to move the map;
- **not** stored, logged, or transmitted to us or any third party.

You can decline the permission and use every other feature normally.

## Network requests to third parties

To display the map and optional overlays, the app fetches data directly from third-party
services. Your device's IP address and the map area you are viewing are necessarily visible to
those services when it requests their data:

- **OpenStreetMap** tile servers (base map) — see the
  [OSMF Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy).
- **Overpass API** (`overpass-api.de`) — points of interest and administrative borders.
- **ÖPNVKarte** and **OpenRailwayMap** tile servers — only if you enable the public-transport
  overlay.

The app sends no identifying information with these requests beyond what any HTTP client sends
(IP address, a descriptive `User-Agent`).

## Crash diagnostics (Sentry)

To find and fix crashes on the variety of devices the app runs on, ZoneCraft sends **crash and
error reports** to [Sentry](https://sentry.io/) (a third-party error-monitoring service). These
reports contain technical diagnostics — error type, stack trace, app version, and device/OS
model — and **do not include** your layers, locations, or any content you create. See
[Sentry's Privacy Policy](https://sentry.io/privacy/).

## Children

The app is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the "Last updated" date above will change accordingly.

## Contact

Questions: open an issue at <https://github.com/LeoStumpf/zonecraft> or email
leo.m.stumpf@gmail.com.
