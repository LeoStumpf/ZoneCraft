# ZoneCraft — Privacy Policy

_Last updated: 2026-08-27_

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
| Data collected about you | None |
| Data sold or shared for advertising | Never |
| Where your content lives | On your device only |
| Advertising ID / device identifier | Not used |
| Analytics, crash reporting or usage tracking | None |

## Data stored on your device

Everything you create — layers, circles, subspaces, freehand lines and areas, height regions,
imported points of interest and transit stations, administrative areas, your settings and
your last map position — is stored **only on your device** in a local database. It is never uploaded to us, and we have no server that could receive it.

Cached map tiles are stored alongside it. These are not personal data — they are pictures of
the map — but they do imply which areas you have looked at, so they are worth naming.

## Location

The app reads your position in exactly one place, which you start yourself.

**"Locate me"** requests **foreground (precise or approximate) location** to centre the map on
your position and read the terrain elevation there. That position is used only to move the map
and **is not stored**. Nothing else in the app reads your position: there is no recording, no
tracking and no background use.

Location is:

- requested **only** when you use that feature — never at launch;
- **never read in the background.** The app has no background-location permission and runs no
  background service;
- never transmitted to us or to any third party, because there is nowhere for it to go.

You can decline the permission and use every other feature normally — "Locate me" is the only
thing that stops working.

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

## What the app can see about your device

Android hides other installed apps from an app unless it declares, in advance and in its
manifest, the specific kinds of thing it needs to hand work to. ZoneCraft declares two, and
they are worth naming because they are the only way it can observe anything at all about what
else is on your phone:

- **Opening a link.** So that the addresses on the About screen can be tapped, the app asks
  whether *something* on the device can open an `https` address. The answer it gets is yes or
  no — not a list of your apps, not which browser, and nothing about any other app you have
  installed. If the answer is no, the address stays as plain selectable text.
- **The system text menu.** A default of every Flutter app: when you select text inside
  ZoneCraft, Android's "share / translate / search" menu is populated by whatever handles
  plain text on your device.

Neither is a query for the list of installed applications, and ZoneCraft does not hold the
Android permission that would allow one (`QUERY_ALL_PACKAGES`). Nothing about your device is
recorded, and nothing is transmitted anywhere — these answers are used once, on screen, and
discarded.

When you do tap a link, ZoneCraft hands the address to your browser and stops being involved.
What happens next is between you and that browser, under its own privacy policy.

## Exporting and sharing your data

**Export** writes your layers to a GeoJSON or KML file. You then choose what happens to it:
**Share** hands it to Android's share sheet, and **Save to file** hands it to Android's document
picker so you can put it wherever you like. Where the file goes is entirely your choice: nothing
is transmitted to us, and the app has no visibility into what you do with it afterwards. Either
way the file is first written to the app's temporary directory, and is removed by the system in
the normal course of clearing app caches. Saving gives ZoneCraft access to the one file you
picked and nothing else — it never gains access to a folder or to your storage generally.

**Importing** works the same way in reverse. You can open a file through the app's file picker,
or share one *into* ZoneCraft from another app — Android grants access to that single file for
long enough to read it, the app copies it into its own cache to import it, and deletes the copy
when it is done. It cannot see anything else the sending app holds.

## Opening a place from another app

ZoneCraft offers itself as a handler for `geo:` coordinates and for
`openstreetmap.org` links, so a place you tap elsewhere can be opened here. Android shows you a
chooser and nothing happens unless you pick ZoneCraft — the links are not "verified App Links",
which would require a domain we control, so ZoneCraft can never quietly take over a link you
meant for another app.

When you do pick it, the app reads the coordinates out of the link and **offers** them: the map
moves there and a card appears. Nothing is written to your database until you choose to add it to
a layer, and nothing about the link is transmitted anywhere. A link ZoneCraft cannot read a
position from is reported as such and discarded.

## Data retention and deletion

Your content is kept until you delete it. There is nothing to request from us, because we hold
nothing:

- **Settings → Clear all data** deletes every layer and object and resets settings.
- **Settings → Clear cached map tiles** empties the tile cache (kept separate, because it is
  cache rather than your data).
- **Uninstalling the app** removes everything, both together.

## Your rights

Because the app collects no personal data about you and holds nothing on a server, there is in
practice nothing for us to disclose, correct or erase — your content is already exclusively in
your hands. If you are in the EU/EEA or UK and believe otherwise, email
<leo.m.stumpf@gmail.com> and it will be handled.

For location, the legal basis is your consent (Art. 6(1)(a) GDPR), given by granting the
permission and revocable at any time in Android's settings. No other processing takes place.

## Children

The app is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the "Last updated" date above changes with it. Material changes will be
noted in the app's release notes.

## Contact

Questions, or anything that looks wrong here: open an issue at
<https://github.com/LeoStumpf/ZoneCraft> or email <leo.m.stumpf@gmail.com>.
