# ZoneCraft → Play Store: what's left (work-tomorrow checklist)

A personal, ordered to-do list for getting ZoneCraft onto the **Internal testing** track for
friends. The repo side is **done** (see "Already done" at the bottom). Everything here needs your
accounts, secrets, or the Play Console, so it can't be automated for you — but each technical step
has a hint/command. Deeper reference: [`RELEASE.md`](RELEASE.md).

Rough order: **1 → 2 → 3 → 4** can be done at your desk tomorrow; **5 → 8** are in the Play
Console (and can partly overlap while account verification is pending); **9** is the final check.

---

## 1. Create a Google Play developer account  ⏳ start first (gates everything)

- [ ] Sign up at <https://play.google.com/console/signup>.
- [ ] Pay the **one-time US$25** fee.
- [ ] Complete **identity + address verification**.

> 💡 Verification for personal accounts can take **a few hours to a few days** — do this first so
> it's ready when the build is. You can fill in store listing details (step 6–8) while you wait.

---

## 2. Generate the upload keystore  🔑 (do once, then guard it forever)

The keystore is the key that proves *you* publish updates. **If you lose it you can't update the
app**, so back it up.

- [ ] Generate it (answer the name/org prompts; remember the passwords):
  ```sh
  keytool -genkey -v -keystore ~/zonecraft-upload.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] Create `android/key.properties` (already git-ignored — never commit it):
  ```properties
  storeFile=/home/leo/zonecraft-upload.jks
  storePassword=YOUR_STORE_PASSWORD
  keyAlias=upload
  keyPassword=YOUR_KEY_PASSWORD
  ```
- [ ] **Back up** `~/zonecraft-upload.jks` + both passwords to a password manager / safe place.

> 💡 `keytool` ships with the JDK; if "command not found", it's under your Flutter/Android Studio
> JDK, e.g. `~/Android/Sdk/jbr/bin/keytool` or `$(dirname $(readlink -f $(which java)))/keytool`.
> 💡 The app's signing config already reads `key.properties` automatically and falls back to the
> debug key when it's missing — so once this file exists, release builds are properly signed.

---

## 3. Create a Sentry project  🐞 (crash reports)

- [ ] Sign up / log in at <https://sentry.io/> (free tier is fine).
- [ ] **Create project → platform: Flutter.**
- [ ] Copy the **DSN** (looks like `https://abc123@o456.ingest.sentry.io/789`).

> 💡 You only need the DSN string — the app reads it at build time (step 4). No code changes.

---

## 4. Build the signed App Bundle (.aab)  📦

- [ ] Build, baking in the Sentry DSN:
  ```sh
  SENTRY_DSN="https://...your-dsn..." scripts/build.sh --bundle
  ```
  Output: `build/app/outputs/bundle/release/app-release.aab`.
- [ ] Confirm it's signed with your **upload** key (not the debug key):
  ```sh
  jarsigner -verify -verbose -certs \
    build/app/outputs/bundle/release/app-release.aab | head
  ```

> 💡 If you want to sanity-test the release build on your phone before Play, generate an installable
> APK set from the bundle:
> ```sh
> # one-time: download bundletool.jar from github.com/google/bundletool/releases
> java -jar bundletool.jar build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
>   --output=zonecraft.apks --mode=universal
> unzip -p zonecraft.apks universal.apk > zonecraft-universal.apk
> adb install -r zonecraft-universal.apk
> ```

---

## 5. Create the app + Play App Signing  🏗️

- [ ] Play Console → **Create app** → name "ZoneCraft", app (not game), free.
- [ ] When you upload your first `.aab`, **accept Play App Signing** (Google holds the real
  app-signing key; your keystore is only the *upload* key — this is the recommended default).

---

## 6. Internal testing release  🚀

- [ ] **Testing → Internal testing → Create new release.**
- [ ] Upload `app-release.aab`, add short release notes, **Save → Review → Roll out**.
- [ ] **Testers** tab → add your friends' **Google-account emails** (up to 100).
- [ ] Copy the **opt-in URL** and send it to them — they open it, tap accept, install from Play.

---

## 7. Store listing + assets  🎨

- [ ] **App name:** ZoneCraft
- [ ] **Short description** (≤80 chars) and **full description** (≤4000).
- [ ] **App icon 512×512 PNG** — resize from `assets/icon/zonecraft.png`.
- [ ] **Feature graphic 1024×500 PNG** — a simple banner (app name on a coloured background works).
- [ ] **≥2 phone screenshots** — capture on your phone:
  ```sh
  adb exec-out screencap -p > screenshot1.png
  # (set up a nice map view first; repeat for a couple of screens)
  ```

> 💡 For the icon/feature graphic, any image editor (or even an online resizer) is fine; they just
> have to hit the exact pixel sizes. Draft store text below — tweak the voice to taste.

### Draft: short description (73/80 chars)

```
Draw map zones, combine them, and narrow down an area. Offline, no login.
```

Alternatives if you want a different angle:

```
Stack map zones — radius, bisector, nearest-point — to pin down an area.
```
```
A private, offline map tool for drawing and combining deduction zones.
```

### Draft: full description (~1,900/4,000 chars)

```
ZoneCraft turns a map into a deduction board. Draw zones, stack them up, and watch
the possible area shrink to exactly where it has to be — perfect for hide-and-seek
style games, geography puzzles, or any "where could it be?" question.

Each layer holds one kind of zone, and you can combine as many as you like:

• Circle — everything within a set distance of a point (true geodesic radius).
• Half-plane — the side of a line that's closer to one point than another.
• Nearest-point cell — the area closest to your chosen point out of several.
• Freehand line — split the map along a line you draw.
• Freehand area — fill any shape you draw.

Overlapping zones merge into one clean colour instead of getting muddier, every
layer can be inverted ("everywhere EXCEPT this"), and an adjustable uncertainty
band shows the fuzzy edge when your information isn't exact.

FEATURES
• Five composable zone types, each on its own colour-coded layer.
• Show/hide, reorder, recolour, rename and invert layers.
• Optional overlays: public-transport lines, points of interest, and
  administrative borders, straight from OpenStreetMap.
• "Locate me" centres the map on your position (only when you tap it).
• The map remembers where you left off.

WORKS OFFLINE
Map tiles you view are cached on your device, and a "Download this area" button
grabs the current view for guaranteed coverage with no signal — handy on the move,
underground, or out of range.

PRIVATE BY DESIGN
No account. No sign-up. Everything you create stays in local storage on your
device — it's never uploaded. Location is only ever used on-device, and only when
you ask for it.

Map data © OpenStreetMap contributors.
```

---

## 8. Compliance forms  📋 (Play won't publish without these)

- [ ] **Privacy policy URL** — host [`PRIVACY.md`](PRIVACY.md) and paste the link (see hint below).
- [ ] **Data safety form:**
  - **Location (approximate + precise):** collected, used for *App functionality*, **not shared**,
    **not required** (optional "Locate me" feature).
  - **Crash logs / diagnostics:** collected and **shared** with a third party (**Sentry**).
  - No data **sold**; no other personal data collected.
- [ ] **Content rating** questionnaire (utility app, no sensitive content).
- [ ] **Target audience:** not directed at children.
- [ ] **App access:** all features work **without a login** (state this so reviewers don't ask for an
  account).
- [ ] **Ads:** none.

> 💡 **Hosting the privacy policy** — easiest option, GitHub Pages:
> Repo → **Settings → Pages → Build and deployment → Deploy from a branch → `main` / root → Save.**
> After a minute it's served at `https://leostumpf.github.io/zonecraft/PRIVACY` (GitHub renders the
> `.md` to HTML). Fallback: paste the contents into a <https://gist.github.com> and use that URL.

---

## 9. After friends install — verify on real devices  ✅

- [ ] Install the **release** build on **2+ different devices** (different Android versions / screen
  sizes) via the opt-in link.
- [ ] Check in a **release** build: **map tiles load** (this proves the INTERNET fix), "Locate me"
  permission prompt + result, **import/export** share sheet + file picker, **"download this area"**
  then airplane-mode panning, screen rotation, and that **Sentry** shows nothing during normal use.
- [ ] Watch **Play Console → Quality → Android vitals** and the **Sentry** dashboard.

---

## ⚠️ Two things not to forget

- **Guard the keystore.** Losing `zonecraft-upload.jks` (or its passwords) means you can't ship
  updates. Back it up now.
- **OSM tile usage policy.** The prefetch + "download this area" features bulk-fetch from community
  tile servers (OpenStreetMap, ÖPNVKarte, OpenRailwayMap). Fine for a handful of friends; if it ever
  grows, switch the base map to a keyed provider (MapTiler / Thunderforest) to stay within policy.

---

## Already done (repo side — no action needed)

- ✅ Fixed the release-blocking bug: `INTERNET` permission now in the main manifest.
- ✅ Release signing config (reads `key.properties`, debug fallback) + secrets git-ignored.
- ✅ App id set to `com.leostumpf.zonecraft` (permanent identity).
- ✅ `scripts/build.sh --bundle` builds a signed `.aab` and bakes in `SENTRY_DSN`.
- ✅ Sentry wired into `lib/main.dart` (only active when a DSN is provided).
- ✅ `PRIVACY.md` + `RELEASE.md` written; `targetSdk 36` (≥ Play's 35); analyze + 78 tests green.
