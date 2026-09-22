# Privacy and permissions

The full policy is [`PRIVACY.md`](https://github.com/LeoStumpf/ZoneCraft/blob/main/PRIVACY.md)
in the repository, and it is written to be read. This page is the short version.

| | |
|---|---|
| Account required | No |
| Data collected about you | None |
| Data sold or shared for advertising | Never |
| Where your content lives | On your device only |
| Anything sent off the device | Only a correction you write and press Send on |
| Advertising ID / device identifier | Not used |
| Analytics, crash reporting or usage tracking | None |
| Backed up to Google Drive | No — deliberately switched off |

## No telemetry, ever

No crash reporting, no analytics, no advertising identifier. A crash reporter was once wired
in and deliberately removed, so that the privacy policy and the Play Store's data-safety form
can both answer *"none"*. **Recent errors** on the About screen is what replaces it: a list
kept in memory for the current run, with a Copy button, never written to disk and never sent.

## Location

Read in exactly one place, which you start yourself: **Locate me**. It asks for foreground
location the first time you press it — never at launch — moves the map, reads the ground
height there, and does not store the position. There is no background location, no
recording, no tracking. Decline the permission and everything else works.

## What leaves the phone

Only requests for what you are looking at or asked for, each to a service named on the About
screen: map tiles from OpenStreetMap (or a provider you configure), imports through Overpass,
place search through Nominatim, terrain tiles for ground height, and — only when you press
**Send** — one note to OpenStreetMap containing what you typed and a position. Every request
carries the app's name and version and nothing that identifies you.

Details of what each service can see, and what the app asks of them in return, are in
[Data Sources and Policies](Data-Sources-and-Policies.md).

## Files

Export writes a file and hands it to the share sheet or the document picker; the app gains
access to that one file and nothing else. Importing works the same in reverse, and a file
shared *into* ZoneCraft is copied, read and the copy deleted.

## Other apps

ZoneCraft declares two things it needs the system to answer: whether *something* can open an
`https` address or a `mailto:` (so the About screen's links and the contact button work),
and the standard text-selection menu. Neither is a list of your apps, and ZoneCraft holds no
permission that would let it ask for one.

## Contact

Leo Stumpf — <leo.m.stumpf@gmail.com>, or the
[issue tracker](https://github.com/LeoStumpf/ZoneCraft/issues).
