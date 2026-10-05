# Map controls

Every button on the map, in the words the app itself uses. The same list is in the app under
**layers menu → What the buttons do**, and each button's long-press tooltip says the same
thing — all three are read from one catalogue, so they cannot disagree.

A button that is **greyed** cannot act right now. It is still live: press it and it says why
("No layer is active — choose one in the layers menu", "Nothing to select yet — add or
import something first", "This layer is hidden, so nothing it does will show"). A button the
layer's *type* can never use is hidden rather than greyed.

## Across the top

| Control | What it does | When it is there |
|---|---|---|
| **Layers** (☰) | Opens the list of layers: add, hide, reorder, recolour, delete. | Always. |
| **Undo and redo** | Takes back the last change, or puts it back. Each names the step it would undo. | Hidden while the tools are hidden. |
| **The active layer** | Names the layer everything else acts on. Tap it for that layer's settings, or to switch to another. | Hidden while the tools are hidden. |
| **Compass** | Points to north. Tap to turn the map back upright. | Only while the map is rotated. |

## Up the right-hand side

| Control | What it does | When it is there |
|---|---|---|
| **Download this area** | Stores the map around you for use with no reception. | Only in a build pointed at a provider whose terms allow downloading ahead. Never on OpenStreetMap's own servers — see [Offline and Map Cache](Offline-and-Map-Cache.md). |
| **Go to place** | Type a town, street or landmark and the map moves there. It searches OpenStreetMap's own place index and changes nothing on your map. | Always. |
| **Locate me** | Finds where you are and marks it, and shows the ground height there for a few seconds. Press again to take the mark away. | Always. Asks for location permission the first time, and only then. |
| **Share my location** | Sends where you are to another app. | Always. |
| **Measure elevation** | Tap anywhere afterwards to read the height of the ground there. | Always. |
| **Measure distance** | Tap two points afterwards for the distance and bearing between them. | Always. |

## Along the bottom

| Control | What it does | When it is there |
|---|---|---|
| **Edit by tapping** (✎) | Turns the map into a chooser: a tap opens whatever you tapped. Reaches anything you can see, on any visible layer. | Always; greyed until some visible layer holds something. |
| **The layer's own switch** | Changes with the layer: **Fill outside / Fill inside** on a region layer, **Colour areas** on a borders layer, the **station filter** on a places layer that holds a station import. Lit while the switch is on. | Only where the layer has one. |
| **Import a shape by name** | Type the name of a city, river or coastline: its outline is fetched from OpenStreetMap and added to this layer. | Only on line and area layers. |
| **Import places in a box** | Fetches places or stations from OpenStreetMap inside a box you mark and keeps them on the device — as markers, or on a circle or subspace layer as circle centres or points. | Only on layers that can hold imported points. |
| **Add** (＋) | Arms the map: the next tap places a new element of the active layer’s kind where you point. On a line or area layer it asks first: point by point, or drawn with your finger. Long-press to place one at the centre instead. | Always. |
| **Hide and show the tools** | Clears the screen down to the map: the column above it, the undo buttons and the layer name all go, and come back. | Always — it is the one thing that survives its own press, along with the layers menu. |

The **map credit** sits at the bottom left, under the button row, whenever the map is showing
(an open editor covers it); tap it for the full list of sources
(OpenStreetMap, and the terrain data behind ground-height layers).

## Why the switch is named by its result

The layer's switch says **Fill outside** rather than *Invert*, because "invert" made people
ask *invert what, into what*. Toggles on the map are named by what is true after you press
them. When a switch is pressed, a one-line tip says what is now true — the first three times.
