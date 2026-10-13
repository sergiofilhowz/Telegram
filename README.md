# Evidence — fix/fold-layout-switch

Screen recordings for the `fix/fold-layout-switch` change (blank/black screen and freezes when
folding/unfolding foldables). English captions in `videos/en/`, Portuguese captions in `videos/`.

## Setup

- Emulator **Pixel 9 Pro Fold**, Android 16 (API 36, `google_apis` x86_64); fold/unfold via `adb emu fold|unfold`.
- `afatDebug` x86_64 APKs built from `master` (`f32ffeec7`) and from the branch (`e38634ca8`), same signature and same app data.
- **Fully mocked, offline account.** The Telegram test DC rejects the test login codes (`PHONE_CODE_INVALID`), so a fake
  account (self user, 7 contacts, chat history) is seeded into the local cache by an instrumentation (`tools/androidTest`),
  and the app's network is blocked by the Android firewall (`cmd connectivity set-package-networking-enabled false`).
  That is why the title shows "Connecting…".
- "Show taps" is enabled so the gesture is visible. The "Swipe up to continue" screen that appears ~1 s after folding is the
  Pixel's default fold behaviour, not the app.

## Videos (`videos/en/`)

| File | Build | Scenario |
|---|---|---|
| `gesture_master_vs_fix.mp4` / `.gif` | both | side by side of the scenario below |
| `gesture_master.mp4` | master | **reproduces**: unfolding during the back gesture leaves the chat list stuck shifted/dimmed; folding again leaves the app rendering nothing (black screen) |
| `gesture_fix.mp4` | fix | same steps, correct layout at every step |
| `background_fix.mp4` / `.gif` | fix | fold/unfold while the app is in background, then return (the scenario reported on the Z Fold 7) |
| `rapid_fix.mp4` | fix | 6 quick fold/unfold toggles with a chat open |
| `deeplink_fix.mp4` | fix | layout mode changes in background, then a chat is opened via link (same path as a notification) |

## How to reproduce

1. Build both APKs (`./gradlew :TMessagesProj_App:assembleAfatDebug -Pandroid.injected.build.abi=x86_64`) from `master` and from
   the branch and copy them to `tools/apks/master-x86_64.apk` and `tools/apks/fix-x86_64.apk`.
2. Copy `tools/androidTest` to `TMessagesProj_App/src/androidTest`, run `assembleAfatDebugAndroidTest` and copy the APK to
   `tools/apks/seed-test.apk`.
3. With a foldable emulator running: `ANDROID_SERIAL=emulator-XXXX tools/scenario.sh install master && tools/scenario.sh make_seed`
   (creates `seed_backup.tar` with the fake account).
4. `tools/rec.sh gesture master`, `tools/rec.sh gesture fix`, etc. Every run restores the same data before recording.
