# ZoneCraft

ZoneCraft builds map areas out of geometric rules. Each rule you add is a **zone** — a coloured
region defined by one simple constraint, like *within 2 km of this point*, *closer to A than to
B* or *above 800 m*. Stack the zones as **layers** over OpenStreetMap, and where they overlap is
the area that satisfies all of them: *"inside the city, but more than 2 km from its border"*.

There is **no login and no server**: every layer, object and setting lives in a local SQLite
database on your phone. Android-first, iOS-ready, built with Flutter, free software under the
AGPL.

## For example

1. *Within 2 km of the station* — add a **circle** there and set its radius.
2. *More than 2 km from it* — press **Fill outside**. The zone becomes everything *except* that
   circle.
3. One **layer per rule**. Where the colours overlap is your area.

## Getting the app

- A closed test on Google Play is being prepared. Until it opens, **build it yourself** —
  see [Building](Building.md); it takes one script and a connected Android phone.
- Source: <https://github.com/LeoStumpf/ZoneCraft>. Issues and feature requests:
  <https://github.com/LeoStumpf/ZoneCraft/issues>.

## User guide

| Page | What it covers |
|---|---|
| [Getting Started](Getting-Started.md) | The first run, your first zone, how the screen is laid out |
| [Layer Types](Layer-Types.md) | The seven kinds of layer and what each one draws |
| [Map Controls](Map-Controls.md) | Every button on the map, and when it is there |
| [Map Modes and Gestures](Map-Modes-and-Gestures.md) | View, select, add, draw, measure — and how the map moves |
| [Layers and Folders](Layers-and-Folders.md) | The layers drawer, the active layer, every per-layer option, folders |
| [Importing from OpenStreetMap](Importing-from-OpenStreetMap.md) | Places, stations, borders, map features by name, GPX tracks |
| [Correcting a Place](Correcting-a-Place.md) | Fixing an imported place by hand and telling OpenStreetMap |
| [Export and Backup](Export-and-Backup.md) | Saving your map to a file — the only backup there is |
| [Sharing a Position](Sharing-a-Position.md) | Sending a place to someone and receiving one |
| [Offline and Map Cache](Offline-and-Map-Cache.md) | What works with no reception, and why nothing is downloaded ahead |
| [Settings](Settings.md) | Every setting, in the order the app shows them |
| [Privacy and Permissions](Privacy-and-Permissions.md) | What the app can and cannot know about you |
| [Known Limits and FAQ](Known-Limits-and-FAQ.md) | Things that are deliberate, not faults |

## Developer

| Page | What it covers |
|---|---|
| [Building](Building.md) | Prerequisites, the build script, every flag and environment variable |
| [Architecture](Architecture.md) | How the app is put together, and the rules that keep it that way |
| [Database and Migrations](Database-and-Migrations.md) | The Drift schema, migrations, snapshots, the GeoJSON format |
| [Data Sources and Policies](Data-Sources-and-Policies.md) | What the app asks of OpenStreetMap's servers — for forkers and operators |
| [Continuous Integration and Releases](Continuous-Integration-and-Releases.md) | CI, where the signed builds are, how a release reaches Play |
| [Contributing](Contributing.md) | Licence, the header every file needs, the gate a change has to pass |

---

> **Transparency:** ZoneCraft was "vibe-coded" collaboratively with Claude (Anthropic's AI
> assistant), which wrote much of the code under human direction.

ZoneCraft is free software: GNU Affero General Public License, version 3 or later. See
[LICENSE](https://github.com/LeoStumpf/ZoneCraft/blob/main/LICENSE). The map data is
© OpenStreetMap contributors (ODbL).
