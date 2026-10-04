# Strait Link — deep-link test app

A small "customer" app used to prove every way a Strait link can open an app.
It integrates Strait **only through the public SDK** (`@strait/sdk-react-native`),
exactly as any other app would.

- **Home = checklist.** Each row is one scenario (tap from Messages with the app
  closed / in background / on screen, tap inside Chrome, deferred install from
  Google Play, fingerprint match, navigation, analytics). Rows turn green by
  themselves when the app sees the scenario work, with the proof underneath.
- **Test links** — real short links on the live engine, with Share / Open as a
  link / Open via browser.
- **Link Inspector** — every link event from the SDK: route, app state,
  received URL, destination, timing.
- **Fingerprint** — compares the app's fingerprint with the browser's on the
  same phone (what iPhone deferred matching relies on).
- **Screens to land on** — product, category, coupon, cart, order (behind
  login), invite, and "link not recognised".

Package `com.straitlink.app` · scheme `straitlink://` · verified link host
`strait-dev.strait.link` (see `AndroidManifest.xml`).

## The SDK integration (all of it)

```ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { PlayInstallReferrer } from 'react-native-play-install-referrer';
import { createStrait, fromPlayInstallReferrer } from '@strait/sdk-react-native';

const strait = createStrait({
  publishableKey: 'st_pub_live_…',            // Dashboard → Get started
  endpoint: 'https://strait-dev.strait.link',
  storage: AsyncStorage,                       // deferred check once per install
  installReferrer: fromPlayInstallReferrer(PlayInstallReferrer),
});
strait.onLink((e) => navigateTo(e.path, e.params)); // every case, one callback
strait.start();
```

See `src/store.tsx` (setup) and `App.tsx` (routing).

## Build

This repo sits next to the SDK in the Strait workspace and installs it from the
local folder as a real package copy (`.npmrc` → `install-links=true`):

```
strait/
├─ sdk-react-native/
└─ samples/AcmeStrait/   ← this app
```

```bash
npm install
npm run sdk:refresh      # after changing the SDK: re-copies it AND clears the
                         # cached release bundle (Gradle doesn't track node_modules)
npm test                 # routing + checklist logic + a real render
npm run build:release    # android/app/build/outputs/apk/release/app-release.apk
cd android && ./gradlew bundleRelease   # .aab for Google Play
```

Release signing reads `android/keystore.properties` + the upload keystore
(both gitignored). Publishing steps: `PUBLISH-PLAY-STORE.md`.

## Automated device test

With the phone connected over USB (`adb devices`):

```bash
scripts/device-test.sh        # ~2 min, prints PASS/FAIL per scenario
```

Checks where each tap really lands: app closed / in background / on screen,
Messages-style and Chrome taps, expired and unknown links, app **not installed**
(store mode → Google Play; auto mode with an unlisted app → the website), and
reinstall. Deferred-after-install needs a real Google Play install.

## Verified on a real phone (Android 16, 2026-10-02)

12 of 14 checklist rows pass: Messages-style taps (closed / background / on
screen), Chrome hand-off (closed / background), product, coupon, login-gated
order, unknown link, expired link, purchase event, and app-vs-browser
fingerprint match. The two deferred rows need the app installed from Google Play.
