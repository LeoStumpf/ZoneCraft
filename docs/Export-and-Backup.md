# Export, import and backup

## Your map lives only on this phone

There is no account and no cloud. The app also deliberately opts **out** of Android's
automatic backup to Google, so a new phone, an uninstall or a lost phone takes the map with
it. **An export is the only copy that survives.** Settings says so beside the button:

> Your map is stored only on this phone. It is not backed up to Google, and uninstalling
> ZoneCraft or losing the phone takes it with them — an export is the only copy that
> survives. Keep one somewhere safe.

Even **Clear all data** offers **Export first** before it deletes anything.

## Exporting

**Settings → Import & export → Export** writes every layer and object; a layer's ⋮ →
**Export layer…** writes that one layer. Both offer two formats and two destinations:

| | |
|---|---|
| **GeoJSON** | ZoneCraft's own format. **Lossless**: import it back and you get exactly the map you exported — every setting, every hidden layer, every folder, every imported point with its OpenStreetMap identity and any correction you made, every generated ground-height fill. |
| **KML** | For Google Earth and Google Maps. A picture of the map, not a backup: it does not round-trip. |
| **Share** | Hands the file to Android's share sheet — send it to yourself, a chat, a drive. |
| **Save to file** | Opens Android's document picker so you can put the file where you like. The app gains access to that one file and nothing else. |

Exported files carry everything Android needs to send them back into the app.

## Importing

**Settings → Import & export → Import** accepts:

- a ZoneCraft GeoJSON export (whole map or single layer), and
- generic **GeoJSON, KML, KMZ and GPX** — tracks, routes and polygons drawn elsewhere come in
  as freehand lines and areas; a line import asks for the radius of its inclusion circle.

Each layer in the file is imported **as a new layer**, or **merged** into an existing layer
of the same type — in which case anything the layer already holds (by OpenStreetMap
identity, for imported points and areas) is skipped rather than drawn twice. A layer's ⋮ →
**Import track…** merges a file straight into that layer.

What arrives is shown on the map first — *is this the right file, and is that the right
place?* — and nothing is written until you press **Keep**.

Foreign files are thinned on the way in (GPS jitter, thousand-point city lines); a file
ZoneCraft wrote itself is not, so exporting and importing again never changes a shape.

### From another app

ZoneCraft is in other apps' **share sheets** for GeoJSON, KML, KMZ and GPX files (and for
"unknown type" files, which is how Android labels a `.geojson`). Share a file to it and the
import starts. The app copies the one file it was handed into its own cache, imports it, and
deletes the copy; it cannot see anything else the sending app holds.

## What deliberately does not survive an export

- When an object was created, and when an import ran or a correction was made — the *fact*
  of a correction travels, the timestamp does not.
- An import that returned nothing.
- The base map's cached tiles. They are pictures of the map, not your data, and are
  re-fetched as you look.

Developers: the format is a fixed point — `export → import → export` is byte-identical, and a
test enforces it. See [Database and Migrations](Database-and-Migrations.md).
