# Continuous integration and releases

## What CI does

`.github/workflows/ci.yml` runs on every push to `main`, every pull request, and on demand
(**Run workflow**). One job, in increasing cost:

1. **Dependencies match the lockfile** — `flutter pub get --enforce-lockfile`, so a bump has
   to be deliberate.
2. **Formatting** — `dart format --set-exit-if-changed lib test`.
3. **Analyze** and **Test** — the same gate `scripts/build.sh` runs.
4. **Release build** — R8 and the native-asset path exist only in release, so a break there
   would otherwise surface the night before a store upload. Through `scripts/build.sh`, never
   a bare `flutter build`, so the dart-defines cannot drift from the laptop build.
5. **Signed with the upload key, not debug** — Gradle's fallback to the debug key is silent,
   so the run fails if either output carries `CN=Android Debug`. Two tools, because the two
   files are signed differently: `apksigner` for the APK (a v2/v3 signature only it reads),
   `keytool -printcert -jarfile` for the App Bundle (a plain jar-signed zip).
6. **Keep the signed build** as a workflow artifact.

Flutter is pinned (3.44.0) rather than `stable`, and the JDK is 21 because that is what
builds the project on the developer's machine.

### The secrets

Five repository secrets make the release build the shippable one. They mirror two files
that live outside version control, so rotating either side means rotating both:

| Secret | Mirrors |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the upload keystore (`.jks`), base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` | `android/key.properties` |
| `TILE_URL`, `TILE_ATTRIBUTION` | `~/.config/zonecraft/release.env` |

The key alias `upload` is a literal in the workflow, not a secret: GitHub masks every
occurrence of a secret's value in the log, and the word "upload" is in half of it.

A fork's pull request sees no secrets. Every step that needs them is gated on
`HAVE_KEYSTORE`, and the debug-signed, OSM-tiled build that results is the smoke test the
workflow started as — deliberately **not** uploaded, because a release-looking APK nobody
can ship would only mislead. Never use `pull_request_target` here: it *would* expose the
secrets to code a fork controls.

## Where the builds are

Every green run on `main` keeps **one artifact**:

- **Name:** `zonecraft-release-<full commit sha>`
- **Contents:** a zip with `flutter-apk/app-release.apk` and
  `bundle/release/app-release.aab`, both signed with the upload key and built against the
  keyed tile provider — the same build `scripts/build.sh --bundle` makes on the laptop
- **Kept for 30 days.** After that, press **Run workflow** on the CI workflow (or push) to
  get a fresh one.

### Downloading it

**On github.com:** the repository → **Actions** tab → the **CI** workflow in the left column
→ click the latest green run on `main` (the run is titled with its commit message) → scroll
to the **Artifacts** box at the bottom of the run's summary page → click the artifact name.
A zip downloads; unzip it.

**From the terminal** (with the [GitHub CLI](https://cli.github.com/)):

```sh
# the build of the commit currently checked out
gh run download -n "zonecraft-release-$(git rev-parse HEAD)" -D ~/Downloads/zonecraft-release

# or pick a run
gh run list --workflow CI --branch main --limit 5
gh run download <run-id> -D ~/Downloads/zonecraft-release
```

Then confirm what you have before uploading it — the same check CI made:

```sh
keytool -printcert -jarfile ~/Downloads/zonecraft-release/bundle/release/app-release.aab | grep Owner
# must not say CN=Android Debug
```

## Releasing to Google Play

Play requires an **App Bundle** (`.aab`); the APK in the artifact is for installing on a
device by hand.

### 1. Bump the version — before the build you intend to ship

The version lives in **two files**: `pubspec.yaml` (`version: 1.4.0+5`) and
`lib/app_info.dart` (`kAppVersion = '1.4.0'`, what the About screen and the User-Agent
show). `test/app_info_test.dart` fails the build if they drift. The number after `+` is the
`versionCode` and must **strictly increase on every upload**, even a re-upload of the same
build — Play rejects a reused one, and the failure reads as an API problem rather than a
numbering one. Commit, push, wait for the run to go green, download that run's artifact.

### 2. Upload

Play Console → **Testing → Closed testing → Create new release** → upload the `.aab` →
paste the release notes (≤ 500 *characters* — count with `wc -m`, not `wc -c`; a `•` is
three bytes) → **Save → Review → Roll out**.

- **First upload only:** accept **Play App Signing**. Google then holds the real signing
  key; the keystore in the secrets is only the *upload* key, which Google can reset if it
  is lost or leaked. That demotion is what makes a keystore in CI survivable.
- **Closed, not Internal**, if production is the destination: a new personal developer
  account has to run a closed test with at least 12 testers opted in for 14 continuous days
  before Google unlocks production access, and internal testing does not count towards it.
- The tester instructions field should say that the map lives only on the phone (export to
  keep a copy) and that **Tell OpenStreetMap** sends a real, public, permanent note that a
  volunteer reads — this build points at the live OSM database on purpose.

### 3. Sanity-test the release build first

The release build is what R8, AOT Dart and the tree-shaken icon font produce, none of which a
debug build exercises. Install it on an **emulator or a second device, not the development
phone**: it is signed with a different key from the debug build, so `adb install -r`
refuses, and the only way through is an uninstall — which takes the map on that device with
it (there is no backup, on purpose).

```sh
# the APK from the artifact is enough for a device
adb install -r ~/Downloads/zonecraft-release/flutter-apk/app-release.apk

# or exactly what Play would install, from the bundle (bundletool from github.com/google/bundletool)
java -jar bundletool.jar build-apks --bundle=app-release.aab --output=zonecraft.apks --mode=universal
unzip -p zonecraft.apks universal.apk > zonecraft-universal.apk
adb install -r zonecraft-universal.apk
```

bundletool re-signs the extracted APK with the local debug keystore and says so; that is not
a signing failure and says nothing about the `.aab` you upload.

What to look at: the welcome sheet on first run, every icon drawn (the icon font is
tree-shaken), and the credit pill at the bottom left — it shows the tile provider's line only
if the dart-define actually reached the bundle.

## Why there is no automatic upload to Play

Continuous delivery to Play is well-trodden (fastlane `supply`, Gradle Play Publisher,
`r0adkll/upload-google-play`) and deliberately not built, for one structural reason and one
judgement: the Play Developer API cannot *create* an app, so the first upload is manual no
matter what; and a closed test is a handful of uploads, and automating a thing done five
times costs more than doing it five times. If it is ever added: pick the `versionCode` scheme
first (it can only go up), and set `OSM_API_URL` explicitly rather than letting a YAML file
inherit the live default.
