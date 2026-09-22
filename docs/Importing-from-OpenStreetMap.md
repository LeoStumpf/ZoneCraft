# Importing from OpenStreetMap

Two layer types hold real OpenStreetMap data, and two more can be *filled* from it. Every
import shares three rules:

- **Only when you ask.** An import runs once, on your press, and is stored on the phone for
  good. It never refetches, never polls, never refreshes — it is a **snapshot** of what
  OpenStreetMap said that day.
- **It can take a minute, and it can fail.** The imports go to Overpass, a volunteer-run
  service, and requests are paced to about one per second. A failed import is kept as a
  **retry row** at the top of the layer's Elements list, with the error and a **Try again**
  button — nothing is silently dropped.
- **You see it before you keep it.** A file or feature import is held in front of the map —
  *is this the right file, and is that the right place?* — and asks **Keep / Discard**
  before anything is written.

## Places layer

A **Places layer** holds three kinds of set, any number of each:

### Places of one kind, around a point

**Import what is nearby → Import nearby POIs…** asks for a category and a radius, then the
next tap on the map is the centre. Categories (from OpenStreetMap's tags): benches, post
boxes, drinking water, toilets, waste baskets, cafés, restaurants, pharmacies, libraries,
aquariums, zoos, golf courses, foreign consulates, transit stations, hospitals, movie
theatres.

Each result is an icon marker. Where markers would overlap they collapse into a **count
badge**; tap a badge for a chip with a **Zoom in** button. Re-importing the same category
skips what the layer already holds.

### Public-transport stations in a box

**Import transit stations…** fetches every station inside a box you tap out (two corners,
or Done for a box around the centre), with which **modes** serve each one — bus, tram,
subway, light rail, train, monorail, ferry. A station's icon is the most significant mode
that stops there.

Once the layer holds a station import, its bottom-row switch and ⋮ → **Stations…** open the
per-type tick boxes, with **Rail only / Show all / Hide all** shortcuts. A station stays
visible while *at least one* ticked type stops there, so "Rail only" keeps the big
interchanges and drops the bus stops. The Elements list carries the same tick box on each
type's heading.

**Line geometry is deliberately never fetched.** Routes proved unobtainable from the public
API at any useful scale, and the stations are what you build zones from anyway.

### A category of your own

**Add** on a places layer offers a **hand-made category**: name it, pick an icon, and every
tap places a marker of that kind. These are yours to move freely. An *imported* point, by
contrast, records what OpenStreetMap returned — correcting one is a deliberate, flagged act;
see [Correcting a Place](Correcting-a-Place.md).

## Borders layer

A **Borders layer** holds administrative areas of one `admin_level` — country, state, county,
city, district… — chosen when the layer is created. **Import borders in view…** fetches every
area of that level that touches a box you tap out.

Two things about the box are easy to get wrong:

- **Whole relations come down.** A boundary clipped to a box has no fillable interior, so the
  app downloads the whole area, assembles its rings on the phone and thins them for drawing.
- **Nothing is cut to the box.** It limits what is *fetched*, not what is *kept*, so an area
  may reach well past what you drew. And the box has to **reach** a boundary, not sit inside
  one — a box wholly inside Bavaria touches no Bavarian border and imports nothing.

Areas are drawn as outlines in the layer colour, with two per-layer switches: **Colour
areas** (a six-colour palette assigned so no two neighbours match — the bottom-row switch)
and **Show names**. Each area has an editor: rename it, move its **name plate**, **Reshape
outline** by hand, or **Convert to freehand area…** — which copies the outer outline into a
freehand area layer you can then edit and combine like anything you drew. A reshaped outline
is flagged *"Reshaped by hand — this outline is no longer what OSM says"*, and that flag
travels with an export, because the area keeps its OSM identity.

## Into a line or area layer

Two imports fill a **freehand** layer rather than a snapshot layer, so what arrives is yours
to edit:

- **Find a place by name / Import map feature…** — type a city, district, river, road, park
  or coastline; the app geocodes it through Nominatim (paced to one request a second, results
  cached) and imports the outline it finds as a freehand area or line.
- **Import track…** — read a **GPX, KML, KMZ or GeoJSON** file into the layer. Tracks and
  routes become freehand lines; polygons become areas. A line import asks for the radius of
  its inclusion circle. Foreign geometry is thinned on the way in; a ZoneCraft export is not.

Both are also reachable from the layer's ⋮ menu and the layer sheet.

## Why some things are slow or refused on purpose

From the app's own About screen — *these are deliberate, not faults*:

- An import can take a minute, and can fail.
- Requests are paced to about one per second.
- The map is never downloaded ahead of what you look at.
- Imports are snapshots, and do not refresh.
- A border box has to reach a boundary, not sit inside one.

[Data Sources and Policies](Data-Sources-and-Policies.md) explains what each service asks of its users, and why the app
holds itself to it.
