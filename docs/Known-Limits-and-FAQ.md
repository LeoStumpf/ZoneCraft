# Known limits and FAQ

## Things that are deliberate, not faults

From the About screen:

- **An import can take a minute, and can fail.** It goes to a volunteer-run service and is
  paced to about one request a second. A failure is kept as a retry row.
- **The map is never downloaded ahead of what you look at.** OpenStreetMap's policy forbids
  it. [Offline and Map Cache](Offline-and-Map-Cache.md) explains, and how a build of your own can differ.
- **Imports are snapshots, and do not refresh.** Re-run the import if the world has changed;
  what the layer already holds is skipped.
- **A border box has to reach a boundary, not sit inside one.** Whole areas come down, and
  nothing is cut to the box.
- **No search-as-you-type** in Go to place: the geocoder's policy forbids it. Type, then
  press search.

## Known for now

- **English only.**
- **The map stays light in dark mode.** Settings and About follow your theme; the map tiles
  have no dark version.
- **Border areas are read-only geometry.** You can rename an area, reshape its outline and
  move its name plate, and **Convert to freehand area…** gives you a copy you can do anything
  with — but a borders layer is a snapshot, not a drawing.
- **No cloud backup, and no sync between devices.** An export is the copy — see
  [Export and Backup](Export-and-Backup.md).
- **Line geometry for transit is not fetched**; stations are.
- Android labels a shared `.geojson` as an "unknown type" file. That is why ZoneCraft accepts
  those; it is not a fault of the file.

## Questions

**Why is the button greyed?** Because it cannot do anything right now. Press it: it says why.
Typically the layer is empty, hidden, or none is active.

**Why did "Fill outside" change nothing on my places layer?** A layer of markers has no
outside; the switch is not offered there. On a region layer it is greyed until the layer
holds a shape.

**Where did my transparency go?** A borders layer without **Colour areas** draws no fill, so
there is nothing to be transparent. The number is kept and applies the moment it has one.

**I long-pressed and nothing opened.** In View mode a long-press offers a chooser of what is
under your finger, and Share / Copy for the spot; a plain tap only shows a chip. Turn on
**Select by tapping** (✎) to make taps open things.

**The map rotated by accident.** It should not: rotation needs a deliberate twist of 20° or
more. Tap the compass to go back to north.

**Can I install the release build over my debug build?** No — they are signed with different
keys, and Android refuses. Uninstalling takes the map with it (there is no backup), so export
first. Developers: see [Continuous Integration and Releases](Continuous-Integration-and-Releases.md).

**Can I run it against my own servers?** Yes — **Settings → Data sources** for tiles,
Overpass and Nominatim at runtime; see [Building](Building.md) for the build-time settings.
