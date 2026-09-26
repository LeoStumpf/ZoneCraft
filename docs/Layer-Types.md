# Layer types

Each **layer** holds one kind of object, and you choose the kind when you add the layer.
Layers can be grouped into **folders** (see [Layers and Folders](Layers-and-Folders.md)).

Five kinds are **regions**: they paint a single flat-coloured area. Overlapping objects within
a layer never darken each other, and the layer's switch, **Fill outside**, fills everything
*outside* the region instead. Two kinds are **imports**: they pull a snapshot of real
OpenStreetMap data, once, and draw it directly.

## Region layers

| In the app | What it draws |
|---|---|
| **Circles layer** | *Everything within a distance of a point — "within 2 km of the town hall".* A true **geodesic** circle: the radius is in real-world metres and is accurate on the globe, which is why it looks like an ellipse at high latitudes on a web map, as it should. |
| **Nearest-point layer** | *Everywhere closer to one point than to any of the others. Two points split the map in half.* A Voronoi cell around a chosen **main** point; with two points it is the "closer to A than to B" half-plane. |
| **Freehand line layer** | *Draw a line to cut an area in two, and keep one side.* A polyline you draw — point by point, or with your finger — that cuts an inclusion circle in two; the layer fills one half, Fill outside fills the other. |
| **Freehand area layer** | *Draw any shape by hand and fill it.* A closed polygon; the layer fills the inside, Fill outside the outside. |
| **Ground-height layer** | *Ground above or below an elevation you choose. Needs the network once, then works offline.* Terrain above or below a height, bounded to a circle, generated once from public terrain tiles and then stored. Any generated region can be **converted to a freehand area** (outer contours; holes are dropped) so you can edit it. |

### The uncertainty band

Every region carries a measurement-uncertainty **band**: a lighter strip drawn just inside the
boundary, on the *coloured* side, so the fill only turns solid a band-width in. It says *"the
region might reach here"*. The width is set once for the whole map in **Settings →
Uncertainty**; 0 turns it off. Bands are always painted below every solid fill, map-wide, so
an uncertain edge never lands on top of a certain one.

### Offset (freehand types only)

A freehand line or area has a signed **offset** in metres. Positive pushes the boundary inward
from the area, or away from the line — *"inside the city **and** more than 5 km from its
border"*. Negative extends the fill past what you drew.

### Fill outside

The switch on the bottom row flips a region layer between **Fill inside** (colour the layer's
shapes) and **Fill outside** (colour everything except them). It exists on circles,
nearest-point, freehand line and freehand area layers. A ground-height layer has no outside
in that sense — its band runs along the elevation contour — and the import layers have no
region to invert. On an empty layer the switch is greyed: there is nothing to invert yet.

## Import layers

| In the app | What it imports |
|---|---|
| **Places layer** | *Import cafés, benches or stations from OpenStreetMap, or place your own markers.* One OSM category, or every public-transport **station**, in a box you tap out — with which types serve it (bus, tram, subway, light rail, train, monorail, ferry). Drawn as icon markers that collapse into count badges when they would overlap. You can also name a category of your own and place its points by hand. |
| **Borders layer** | *Download real district, city or country outlines once and keep them offline.* Administrative areas of one OSM `admin_level`, chosen when the layer is created. Whole relations come down and are assembled on the phone; **nothing is cut to the box** — it limits what is downloaded, not what is kept. Optional neighbour-distinct colouring and name plates; any area can be **converted to a freehand area** you can then edit. |

Imports run once, on your explicit request, and are stored offline. They never refetch and
never poll. [Importing from OpenStreetMap](Importing-from-OpenStreetMap.md) has the details.

## Every layer has an editor

Tap anything with **Select by tapping** on (or long-press it in the default mode) and its
editor docks at the bottom: a circle's centre and radius, a nearest-point's points, a line's
vertices, an imported place's name and position, a border area's outline. Every number is
typeable, and coordinates take one *"lat, lng"* field that accepts values pasted straight
from Google Maps — with either decimal separator.
