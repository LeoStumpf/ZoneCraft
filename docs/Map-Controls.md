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
| **Locate me** | Finds where you are and marks it, with the ground height there. Press again to take the mark away. | Always. Asks for location permission the first time, and only then. |
| **Share my location** | Sends where you are to another app. | Always. |
| **Measure elevation** | Tap anywhere afterwards to read the height of the ground there. | Always. |
| **Measure distance** | Tap two points afterwards for the distance and bearing between them. | Always. |
| **Draw with your finger** | Trace a line or an area instead of tapping point by point. One-finger panning is off while this is on. | Only on a layer that holds lines or areas. |

## Along the bottom

| Control | What it does | When it is there |
|---|---|---|
| **Select by tapping** (✎) | Turns the map into a chooser: a tap opens whatever you tapped. Reaches anything you can see, on any visible layer. | Always; greyed until some visible layer holds something. |
| **The layer's own switch** | Changes with the layer: **Fill outside / Fill inside** on a region layer, **Colour areas** on a borders layer, the **station filter** on a places layer that holds a station import. Lit while the switch is on. | Only where the layer has one. |
| **Find a place by name** | Searches OpenStreetMap for a city, river or coastline and imports its outline. | Only on line and area layers. |
| **Import what is nearby** | Fetches places or transit stops from OpenStreetMap into this layer and keeps them on the device. | Only on layers that can hold imported points. |
| **Add** (＋) | Arms the map: the next tap places a new element where you point. Its icon shows which kind. Long-press to place one at the centre instead. | Always. |
| **Hide and show the tools** | Clears the screen down to the map: the column above it, the undo buttons and the layer name all go, and come back. | Always — it is the one thing that survives its own press, along with the layers menu. |

The **map credit** at the bottom left is always visible; tap it for the full list of sources
(OpenStreetMap, and the terrain data behind ground-height layers).

## Why the switch is named by its result

The layer's switch says **Fill outside** rather than *Invert*, because "invert" made people
ask *invert what, into what*. Toggles on the map are named by what is true after you press
them. When a switch is pressed, a one-line tip says what is now true — the first three times.
