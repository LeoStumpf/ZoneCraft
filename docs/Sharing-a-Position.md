# Sharing a position

## Sending one

- **Long-press the map** (in the default View mode) → **Share** or **Copy**. The message
  carries a `zonecraft://` link **and** the plain coordinates, so it is useful to someone
  without the app too.
- **Share my location** (the right-hand column) does the same for where you are.

*"Share this place"* hands the text to Android's share sheet: a chat, an email, a note.

## Receiving one

Three ways in, all of which **write nothing** until you say so:

| Route | What happens |
|---|---|
| Tap a `zonecraft://` link in a chat | ZoneCraft opens, the map glides there and a card appears. |
| Tap a `geo:` link or an **openstreetmap.org** link anywhere | Android shows a chooser; pick ZoneCraft and the same card appears. ZoneCraft never claims a link without asking — the links are not "verified" App Links, which would need a domain. |
| Paste the message | **Settings → Shared places → Paste coordinates**: paste the whole chat message — a `zonecraft://` link, a map link, or just the coordinates with the words around them — and the app finds the position in it. The box is pre-filled from the clipboard. |

The card shows the position and offers **Add to layer…**; until you press it, the position
is only on screen. The map never zooms *out* to show a received place — it goes to at least
street level and stays closer if you already were.

A link the app cannot read a position from is reported as such and discarded.
