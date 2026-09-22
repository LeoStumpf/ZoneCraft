# Offline and the map cache

## What works with no reception

- **Everything you have drawn and imported.** Layers, regions, imported places, stations and
  borders, generated ground-height fills — all of it is on the phone.
- **Every map tile you have looked at.** Tiles are stored as they are displayed and served
  from the phone first, so revisiting an area does not re-download it and the map keeps
  working underground. The cache is capped at 200 MB; the oldest tiles go first. **Settings →
  Offline map cache** shows its size and has a **Clear cached map tiles** button, separate
  from *Clear all data*.

What does *not* work offline: a new import, Go to place, Measure elevation and generating a
new ground-height region (the terrain tiles come from the network), and sending a
correction. Each says so rather than failing quietly.

## Why nothing is downloaded ahead of you

ZoneCraft does **not** pre-fetch map tiles, and has no "download this area" button in the
default build. OpenStreetMap's servers are run on donations, and their
[tile usage policy](https://operations.osmfoundation.org/policies/tiles/) defines bulk
downloading as *"any pre-emptive fetching of tiles other than those a user is actively
viewing"* and states that *"offline use is not permitted on tile.openstreetmap.org"*. There is
no compliant amount of it, so on the community servers the app fetches only what you are
looking at. Caching what it *did* show you is a separate thing — the policy requires that, and
it is always on.

A build pointed at a tile provider of your own, **and** told that its terms allow
pre-fetching, gets both the viewport prefetch and a **Download this area** button back. They
are two separate switches on purpose: leaving OpenStreetMap does not by itself buy
permission, since the commercial providers forbid pre-downloading on their cheaper plans too.
See [Building](Building.md) and [Data Sources and Policies](Data-Sources-and-Policies.md).

## When the map stops loading

A server that *answers* and says no — a spent daily quota on a keyed provider, a refused key,
a blocked client — looks exactly like a broken app, at an hour nobody can predict. So when
three tiles in a row are refused, a banner says so — *"The map has stopped loading new
areas"* or *"The map server is refusing this app"* — with a **Why?** that explains what it
means and that your data is untouched. Simply being offline raises nothing: not reaching the
server is the normal state the cache exists for. Any successful tile clears the banner.

## Data sources of your own

**Settings → Data sources** points the map tiles, the imports and the place search at servers
you run, without rebuilding the app. It cannot switch pre-fetching on: that stays a
build-time statement about terms somebody has read.
