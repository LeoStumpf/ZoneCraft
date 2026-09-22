# Settings

The layers menu → **Settings**. Sections in the order the app shows them, with the app's own
explanations.

## Uncertainty

> A measurement-uncertainty band drawn lighter just inside every object's border, before the
> fill turns solid. Set to 0 to disable.

One radius in metres, for every region on the map. See *The uncertainty band* in
[Layer Types](Layer-Types.md).

## Offline map cache

> Map tiles you view are stored on the device, so revisiting an area works without
> re-downloading it — including with no reception. Tiles are never fetched ahead of what you
> look at.

Shows **Cached map tiles: ‹size›** and offers **Clear cached map tiles**, which touches nothing
but the tiles. See [Offline and Map Cache](Offline-and-Map-Cache.md).

## Import & export

> Save all layers and objects to a file to share or back up. GeoJSON imports back into the
> app; KML is for Google Earth / Maps. Import accepts ZoneCraft GeoJSON plus generic GeoJSON,
> KML/KMZ and GPX, either as new layers or merged into an existing one. You can also export
> or import a single layer from the layers drawer.

And the warning that matters most in the whole app:

> Your map is stored only on this phone. It is not backed up to Google, and uninstalling
> ZoneCraft or losing the phone takes it with them — an export is the only copy that
> survives. Keep one somewhere safe.

**Export** / **Import** — see [Export and Backup](Export-and-Backup.md).

## Shared places

> Someone sent you a position? Paste their message here — a zonecraft:// link, a map link,
> or just the coordinates with the chat around them. Long-press anywhere on the map to share
> a place back, or use the share button for where you are.

**Paste coordinates** — see [Sharing a Position](Sharing-a-Position.md).

## Data

> Delete every layer and object and reset all settings to their defaults.

**Clear all data** asks first — *"This deletes every layer and object, empties your
OpenStreetMap outbox and resets all settings. This cannot be undone. Reports you have already
sent stay on OpenStreetMap — only this device's copy of them goes."* — and offers **Export
first**.

## About ZoneCraft

*"Version, the services it contacts, and what it deliberately will not do."* The About screen
names every service the app talks to and links to **Servers and limits** (what the app asks
of them, and how an operator reaches a human), the privacy policy, the licence, the
open-source licences of everything bundled, and **Recent errors** — kept in memory for this
run only, never written to disk, never included in an export, never sent anywhere; it has a
Copy button for a bug report.

## Data sources

Collapsed by default. *"Point the app at your own map, import or search server."*

> ZoneCraft borrows three services that other people pay to run. Leave these empty unless you
> host your own — the app works as it is, and every request it makes is one you asked for.

| Field | Help text |
|---|---|
| **Map tiles** | A `{z}/{x}/{y}` template. Offline downloading stays off whatever you put here. |
| **Overpass imports** | Tried first; the public instances stay as a fallback. This is the one that matters — a border import can pull tens of megabytes off a donated server. |
| **Place search** | A host name only, without `https://` or a path. |

Each field shows its built-in default. Where a correction to OpenStreetMap is sent is
deliberately **not** here — see [Correcting a Place](Correcting-a-Place.md).

## Tips

> The map's buttons are icons without labels. Pressing one of the layer switches answers
> with a line saying what is now true — a few times each, then it stops. "What the buttons
> do" in the layers menu explains all of them at any time.

**Explain what buttons do** (off stops the tips now) and **Show all tips again**, which also
brings back the welcome sheet.
