# Correcting a place, and publishing it to OpenStreetMap

The places on a POI layer are yours: imported ones record what OpenStreetMap returned, and you
can add your own. When you change something for yourself — add a bench, fix a name, move a
place to where it really is, delete one that is gone — the app can pass that change on to
OpenStreetMap. Only a change of your own is ever offered; an untouched import *is* what
OpenStreetMap has, so there is nothing to say about it.

## Editing a place

Open the point (Select by tapping, or from the Elements list). Its editor shows the facts, each
with the button that changes it:

- **Name** — shown as text, with **Edit**.
- **Position** — shown as coordinates, with **Edit** (type a new one) and **Move** (tap the map
  where it really is).

**Edit** opens a small dialog with **Save** and **Save & publish…** — the second saves and then
opens the publish sheet below, describing the change you just made.

On an imported place, the moment the name or position changes the row is marked **corrected**:
the editor says *"Corrected by you. OpenStreetMap still has …"* with what the import returned,
and offers **Revert**. A move that ends where it started is not a correction.

The mark matters because the point keeps its OpenStreetMap identity. Without it, your guess
would silently beat whatever OpenStreetMap says next time — and, in an exported file, would
arrive on another phone looking like "what OSM says". So the flag travels with an export, the
original values alongside it, and a re-import keeps your corrected version knowingly.

## Deleting a place

**Delete** always asks first. For an imported place the question offers a third answer,
**Delete & tell OSM…**, which files *"This does not seem to be here any more"* with the same
sheet before your copy goes. A place you added yourself was never on OpenStreetMap, so it is
only asked about. Undo brings a deleted place back.

## Publishing

A place with something to publish shows **Publish to OpenStreetMap…** (one you added) or
**Publish this change…** (a correction) in its editor, and its row in the Elements list says
*not published*, *in your OSM list* or *sent to OSM*. The sheet holds a draft you can edit —
*"What should a mapper know?"* — that says what the place is (its category and OpenStreetMap
tag, e.g. `amenity=bench`), where it is, and what changed: the old and new position with the
distance and direction between them, the old and new name, or for a new place the tags a
mapper would type. It is signed with the app's name and version. Three ways out:

| Button | What happens |
|---|---|
| **Send now** | One anonymous **note** is filed on OpenStreetMap, at the place's position. |
| **Keep in my list** | The report goes to the **outbox** (**OpenStreetMap outbox** in the layers menu, shown once it holds something), from where it can be sent another day — or **exported as GeoJSON** to work through in JOSM or iD under your own account. |
| **Copy** | The text goes to the clipboard. |

The sheet's warning is always shown and never goes quiet:

> This goes to OpenStreetMap's volunteer mappers. It is public and permanent, and it is for
> map data only — not for feedback about ZoneCraft. Please don't include personal
> information.

A volunteer has to read and close every note by hand, so please only send one for a real
map error you have actually seen. Feedback about the app belongs in the
[issue tracker](https://github.com/LeoStumpf/ZoneCraft/issues).

### The limits the app holds itself to

OpenStreetMap publishes no hard limit on anonymous notes, so the app sets its own, matching
what osm.org itself allows an anonymous visitor:

- After **5 reports in a day** the sheet says so, and suggests saving and exporting instead.
- After **10** the Send button is withdrawn until tomorrow. Keep in my list and Copy still work.

A block for abuse would land on the app's `User-Agent` — that is, on every install at once —
which is why the numbers are conservative.

### What is deliberately *not* built

- **No edits, only notes.** The app keeps no tag map and no element version, so a direct edit
  would strip data off live objects. A note — the route OpenStreetMap's own guidance sanctions
  for third-party apps — is the only honest report this data can make.
- **No retry, no batch, no timer.** A note that timed out may well have been filed; sending it
  again would file it twice. Nothing in the outbox is ever sent without a press.
- **Nothing else leaves the phone.** A note carries what you typed and the position — no
  identifier of you or your device. See [Privacy and Permissions](Privacy-and-Permissions.md).

Developers: the note goes to `OSM_API_URL`, a build-time setting; point it at
`https://master.apis.dev.openstreetmap.org` when testing, so a volunteer never has to close a
note filed to see whether a button works. See [Building](Building.md).
