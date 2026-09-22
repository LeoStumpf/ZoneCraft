# Map modes and gestures

The map is always in exactly one **mode**. Pressing the button of the mode you are in returns
to the default. A banner across the top says what the current mode wants from you.

## Modes

| Mode | How you get there | What a tap does |
|---|---|---|
| **View** (default) | Press Done, or the active mode's button again | **Nothing changes.** Panning and pinching never open an editor. A tap may show an **info chip** naming what is under your finger — its **Edit** button is the deliberate act. Long-press instead for a ranked chooser of everything under your finger, or to share that spot. |
| **Select by tapping** (✎) | The ✎ button on the bottom row | *"Tap an element to edit it."* A tap opens whatever you hit, on **any visible layer** — choosing it makes that layer active. With something selected: *"Tap another element · empty map deselects."* |
| **Add** | The ＋ button | Sticky: each tap places one element (*"Tap to place…"*, *"3 added · tap for more"*). For a box import: *"Tap one corner of the area"*, then the opposite one. Undo / Edit / Done live in the banner. Long-press ＋ to place at the centre. |
| **Draw with your finger** | The pencil in the right-hand column, on a line or area layer | *"Drag one finger to draw · two fingers pan."* Lift to finish; draw another straight away. |
| **Measure elevation** | The right-hand column | *"Tap the map to measure."* Reads the ground height at any point; also shows your own if Locate me is on. Needs the network for the terrain tiles: *"Elevation data unavailable here (offline?)"* when it cannot. |
| **Measure distance** | The right-hand column | *"Tap two points."* Then the distance and bearing between them. |

A **cluster badge** (a count where markers would overlap) behaves like an element in View
mode: tapping it raises an info chip — *"12 POIs · layer"* — with a **Zoom in** button. The
map never zooms on its own from a tap.

## Editing what you placed

- **Handles.** A selected object's points are draggable, and the region reshapes live as you
  drag. Long-press a handle for its menu (delete, make main, …). Long-press the map to insert
  a vertex on a line or area.
- **The editor sheet** docks at the bottom and writes every change live while the map stays
  interactive. It collapses to a grip bar so you can reach the map behind it. Every number is
  typeable; coordinates take one *"lat, lng"* field.
- **Border outlines** are reshaped in a mode of their own (the area's editor → **Reshape outline**),
  because a boundary carries hundreds of vertices where a drawn area carries eight. A
  reshaped outline is flagged as edited — see [Importing from OpenStreetMap](Importing-from-OpenStreetMap.md).
- **Undo / redo** on the top row take back any change to the map, up to 50 steps, and each
  names the step it would undo. Pressing a button that only *explains* something, or sending
  a report, is not a step.

## Gestures

The map follows Google Maps:

| Gesture | Effect |
|---|---|
| One finger | Pan (except in Draw mode, where it draws; two fingers still pan). |
| Pinch | Zoom, around the fingers. |
| **Double-tap** | Zoom in at the finger. Off only while a tap *places* something — two quick corner taps must not become a zoom. |
| **Two-finger tap** | Zoom out around the fingers. |
| **Twist** | Rotates the map — but only a deliberate twist of 20° or more, so a wobbly pinch never turns it. The compass appears; tap it to go back to north. |
| Long-press on the map | In View mode: a chooser of what is under your finger, plus **Share / Copy** for the spot. In Add mode on a line or area: insert a vertex. |

Every move the app makes by itself — Locate me, Go to place, Zoom to, a received link, an
import fit, a cluster's Zoom in — glides rather than jumps. A gesture of yours stops it.
Locate me and a received link never zoom you *out*: they go to at least street level and
stay closer if you already were.
