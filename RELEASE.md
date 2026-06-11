# Releasing ZoneCraft to Google Play (internal testing)

Repeatable checklist for shipping a build to friends via the **Internal testing** track.
The repo is already wired for this (release signing config, `--bundle` build, Sentry,
INTERNET permission). What remains is mostly one-time account/keystore setup + the Play Console.

## One-time setup

### 1. Google Play developer account
- Create one at <https://play.google.com/console> — **one-time US$25**, plus identity/address
  verification (can take a few days for personal accounts). Do this first; it gates everything.

### 2. Upload keystore (keep it safe — losing it means you can't update the app)
```sh
keytool -genkey -v -keystore ~/zonecraft-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Then create `android/key.properties` (gitignored — never commit it):
```properties
storeFile=/home/leo/zonecraft-upload.jks
storePassword=********
keyAlias=upload
keyPassword=********
```
Back up the `.jks` file and passwords somewhere safe (password manager).

### 3. Sentry project
- Create a free project at <https://sentry.io/>, choose **Flutter**, copy the **DSN**.

## Each release

1. **Bump the build number** in `pubspec.yaml` (`version: 1.0.0+1` → `+2`, …). Play rejects a
   reused `versionCode`.
2. **Build the signed App Bundle:**
   ```sh
   SENTRY_DSN="<your-dsn>" scripts/build.sh --bundle
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.
   Confirm it's signed with the **upload** key (not debug):
   ```sh
   jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | head
   ```
3. **Play Console → your app → Testing → Internal testing → Create new release.**
   - First time: accept **Play App Signing** (Google holds the app-signing key; your keystore is
     just the upload key).
   - Upload the `.aab`, add release notes, **Save → Review → Roll out**.
4. **Testers:** add their Google-account emails to the internal-testing tester list, then share
   the **opt-in URL** Play gives you. They open it, accept, and install from Play.

## First-time store/compliance (Play won't publish without these)

- **Store listing:** app name "ZoneCraft", short description (≤80 chars), full description
  (≤4000), **512×512** icon, **1024×500** feature graphic, **≥2** phone screenshots
  (capture on-device).
- **Privacy policy URL:** host `PRIVACY.md` (GitHub Pages or a Gist) and paste the URL.
- **Data safety form:** declare
  - **Location (approximate + precise)** — collected, used for *App functionality*, **not shared**,
    not required (optional feature).
  - **Crash logs / diagnostics (via Sentry)** — collected and **shared** with a third party
    (Sentry) for app functionality/analytics.
  - No data sold; no other personal data collected.
- **Content rating** questionnaire (utility app, no objectionable content).
- **Target audience & content:** not directed at children.
- **App access:** all features work **without an account/login** (note this so reviewers don't
  need credentials).
- **Ads:** none.

## After friends install

- Watch **Play Console → Quality → Android vitals** (crashes/ANRs) and the **Sentry** dashboard.

## Notes / cautions

- **Keep the keystore forever.** If lost, you must reset the upload key with Google (possible)
  but cannot change the app-signing key.
- **OSM tile usage policy:** the prefetch + "download this area" features bulk-fetch from
  community tile servers (OSM, ÖPNVKarte, OpenRailwayMap). Fine at friends-scale; if usage grows,
  switch the base map to a keyed provider (MapTiler/Thunderforest) to stay within their policies.
- **KGP build warning** from `share_plus`/`package_info_plus` is upstream and harmless (see
  `IMPLEMENTATION_PLAN.md`).
