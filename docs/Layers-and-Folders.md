# Layers and folders

## The layers drawer

☰ at the top left opens the drawer: one row per layer, in drawing order (top of the list is
drawn on top). Each row has a **visibility switch**, a colour swatch, the layer's name and
type, and a ⋮ menu with everything below. Drag the handle to **reorder**. Tap a row to make
that layer the **active** one — the layer that Add, the imports and the layer switch act on.

The drawer also has:

- **Add** — pick one of the seven [Layer Types](Layer-Types.md); the new layer becomes active. The same
  menu adds a **Folder** — *"Group layers to hide or invert together"* — see below.
- **Map** — a pinned bottom row for the base map itself: hide it or dim it like any other
  layer. It can never be deleted or reordered.
- **What the buttons do** — the guide to every [map control](Map-Controls.md).
- **OpenStreetMap outbox** — corrections saved for later (see [Correcting a Place](Correcting-a-Place.md)).
- **Settings**.

## The active layer, without opening the drawer

The chip on the top row (swatch · type · name) opens the **layer sheet**: a row to switch
layers, and every setting of the active layer as a direct control — two taps from the map to
anything the drawer's ⋮ offers. Beside Edit on the bottom row, the layer's own **switch**
(Fill outside, Colour areas, or the station filter) is a one-tap shortcut to the one setting
you reach for most.

## Every per-layer option

Defined once, shown in three places — the drawer's ⋮, the layer sheet, and (for the switch)
the bottom row — in the app's own words:

| Option | What it does |
|---|---|
| **Move to top / up / down / to bottom** | Draw this layer above every other one, one place higher, one place lower, below every other one. |
| **Rename** | Give this layer a different name. |
| **Colour** | Pick the colour this layer's elements are drawn in. |
| **Transparency…** | Make the whole layer more or less see-through. |
| **Fill outside / Fill inside** | Colour everything except this layer's shapes / colour this layer's shapes rather than everything around them. Region layers only; greyed while the layer is empty. |
| **Stations…** | Choose which kinds of station are shown on the map. Places layers holding a station import. |
| **Colour areas** | Give each area a colour, chosen so no two neighbours match. Borders layers. |
| **Show names** | Print each area's name across it. Borders layers. |
| **Import nearby POIs…** | Fetch places of one kind — cafés, benches — around a point. |
| **Import transit stations…** | Fetch public-transport stops inside a box you draw. |
| **Import borders in view…** | Fetch administrative areas covering the current view. |
| **Import map feature…** | Search OpenStreetMap by name and import the shape it finds. |
| **Import track…** | Read a GPX, KML or GeoJSON file into this layer. |
| **Export layer…** | Save this one layer to a file, or share it. |
| **Combine…** | Move everything from this layer into another one. Shown only when there is a layer it could go into. |
| **Move to folder… / Move out of folder** | Put this layer in a folder, to hide or invert as a group; take it back out on its own, unchanged. |
| **Delete** | Remove the layer and everything on it. Ends in a snackbar with **Undo**. |

An option that cannot act right now is greyed and says why beneath itself; one the layer's
type can never use is not shown.

## Element colours

Every element paints a **shade** of its layer's colour by default — same hue, slightly
different lightness — so neighbouring elements tell each other apart and all follow when the
layer is recoloured. Any element can be given its own colour in its editor. Within a layer the
front-most element wins an overlap, and fills stay flat; a layer set to Fill outside stays a
single colour, because its fill is the complement and belongs to no element.

## The Elements list

Every layer row carries a list button (≡), always, whatever the layer's type or state:
reaching an element must never depend on either. It opens the **Elements** list of what the
layer holds: each element with its ground length or
area where it has one, searchable, and sorted by the **Sort** button above the search field —
by name, by size, in stack order, by **distance from you** or by **distance from the map
centre**. The sort applies inside each type of place too, so "which bench is nearest" is one
tap. Distance from you asks for your location the first time you choose it, exactly as
**Locate me** does, and never before.

Each place in the list carries a **small map of the streets around it**, with the place marked
in the middle, and a line saying how far it is from you and from the map centre — so two
unnamed benches are still two different benches. The little maps are the same tiles the map
itself has shown, so they cost nothing extra and work offline wherever you have looked;
somewhere you have never looked shows a plain square. A place you corrected by hand says
**edited**. Each row offers **Edit**,
**Zoom to**, **Rename**, **Delete**, and **Bring to front / Send to back**. On a places layer
the points are filed by what they are, never by how they arrived — a category across every
import of it *and* your own category of the same thing (a bench you placed sits with the
imported benches), a station under its main mode — and a station type's heading carries the
same tick box as **Stations…**. A heading's menu offers **Zoom to**, **Edit category** for a
category of your own, and **Delete** for everything under it. The only trace of an import is
a **failed one's retry row, which floats to the top** so no fold can hide it. A border area's row offers **Convert to freehand area…**.

## Folders

A folder groups layers **without merging them**. Each member keeps its own colour,
transparency and settings, and can be taken out again unchanged. A folder offers exactly
three things:

- **Hide** the whole group (a member is shown when it *and* its folder are shown).
- **Fill outside** the whole group — which flips each member's *own* switch: a member that
  was already filled outside goes back to inside, because that is what makes a switch a
  switch. Nothing is composited across layers.
- **Collapse** it, so seven settled layers take one line.

A folder paints nothing, so it has no colour and no transparency. Drag a layer onto a
folder to put it in; drag it out, or use **Move out of folder** for the case a drag cannot
express (the last member leaving downwards). A folder drags as a block and never lands inside
another. **Deleting a folder keeps its layers** — getting layers back out is the thing the
old "combined layer" could never do, so deleting the group must never delete its contents
by accident.

In the drawer a member says *"· inverted (folder)"* when its own switch and the folder's
differ, so the drawer and the map never appear to contradict each other.
