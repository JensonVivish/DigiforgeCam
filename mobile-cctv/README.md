# DigiforgeDynamics CCTV (prototype)

Turn a spare Android phone into a live security camera and watch it from another phone.
No subscription, no server of your own. WebRTC streams peer-to-peer; Firebase Realtime
Database is only used for the pairing handshake.

```
mobile-cctv/
  shared/       theme, brand mark, Firebase REST client, pairing code, clips browser
  camera_app/   runs on the spare phone
  viewer_app/   runs on your phone
  tools/        CI helper that patches the generated Android project
```

## 1. Create the Firebase database (once, ~2 minutes)

1. Firebase console -> create a project -> **Build -> Realtime Database -> Create database**.
2. Open the **Rules** tab and paste this (prototype rules), then Publish:

```json
{
  "rules": {
    "cams":   { ".read": true, ".write": true },
    "config": { ".read": true, ".write": false }
  }
}
```

3. Copy the database URL (looks like `https://my-project-default-rtdb.firebaseio.com`) and paste it into
   `shared/lib/src/config.dart` in place of the placeholder.

No `google-services.json` and no Firebase SDK are needed; the apps talk to the REST API.

## 2. Build the APKs

Push this repo to GitHub. The **Build APKs** workflow runs on every push (or run it manually
from the Actions tab). Download `digiforge_cctv_camera-apk` and `digiforge_cctv_viewer-apk`
from the run's artifacts and install them.

Local build (needs Flutter 3.27+): inside `camera_app/` or `viewer_app/` run
`flutter create --platforms=android --org com.digiforgedynamics --project-name <pkg> .`,
then `bash ../tools/prepare_android.sh "DigiForge Camera"`, then `flutter run`.

## 3. Use it

1. Install **DigiForge Camera** on the spare phone, open it once and tap **Allow all**. When everything is allowed
   it closes itself; the camera keeps running in the background and starts by itself after a restart.
2. Open **DigiForge Viewer**. It lists every camera that is online. Tap one to watch.
3. On the viewer, tap **Record clip** to save an mp4 (Clips tab). Use the flip button to switch front/back camera.

There is no pairing code or QR in this prototype: every camera that is online shows up in the viewer.

## Camera app: background, startup, permissions

Built for older phones: Android 5.0 and up, tuned for Android 5 to 10 (Samsung and Realme included).

- **Install, then tap Open once.** Android never opens a sideloaded app by itself after a first install (only the
  installer's own "Open" button can). The first launch shows Android's permission dialogs one after another
  (camera, microphone, notifications on Android 13+, keep running in background). Tap Allow on each; no Settings app.
  The camera is NOT started for this. Then the screen closes itself.
- **After setup the app never shows again.** The launcher icon is an invisible gate: tapping it only makes sure the
  background service is running and disappears immediately. (If a permission is later taken away, it opens the
  setup screen again.)
- **Camera and mic are off until you ask.** The camera app runs all the time as a light background service that
  only watches for requests. The camera and microphone turn on when you press **Turn on** in the viewer, and turn off
  ~15 s after the last viewer leaves or when you press **Turn off camera**. Turning on takes a second or two.
- **Background:** a foreground service keeps the app alive with the screen off and after it is swiped away. If the
  phone kills it anyway, it asks Android to start it again. The notification's **Stop** button ends everything.
- **Start after restart:** on Android 10 and older the service starts from the boot broadcast with nothing on
  screen. On Android 11+ the invisible gate opens briefly. On some phones (notably Realme) Android blocks apps from
  starting at boot unless "Auto launch / Autostart" is allowed for the app in the phone's own settings; an app cannot
  switch that on itself, so if the camera is not listed in the viewer after a restart, check that setting once.
- **Pairing speed:** both sides check Firebase twice a second during connection; a free public relay is used as a
  fallback only when a direct connection is impossible (strict mobile networks). Add your own TURN at `config/turn`
  to replace it.
- **Camera trouble is handled silently:** if the camera cannot open (busy, other app, microphone in use) the app
  retries with simpler settings (other lens, video only). No error screens.
- **Another camera app takes the camera:** the stream stops; the viewer keeps reconnecting and the camera app
  takes the camera back as soon as it is free. A frozen picture is detected within ~15 s and the camera restarts.
- **Front/back camera:** switch from the viewer. The request goes over two paths (peer-to-peer channel and Firebase)
  with an explicit target, so it cannot toggle back; if the phone refuses a live switch, the camera reopens on the
  other lens and the viewer reconnects. Old phones cannot open both lenses at once.
- **Firebase cleanup:** the viewer removes cameras that have been offline for over a day (or that only left stray
  data behind). A camera recreates its entry by itself when it comes back.

The camera captures at 640x480, 15 fps. Change `kCaptureWidth/Height/Fps` in `camera_app/lib/camera_service.dart`.

## Test checklist (on real phones)

1. Install both apps. Camera phone: tap Open in the installer, tap Allow on each dialog; it should say All set and close, and the camera light must NOT turn on. Tapping the app icon afterwards must show nothing.
2. Viewer: the camera appears in the list (model name) within ~5 s. Press **Turn on**: video + sound within a few seconds.
   Press **Turn off camera**: the camera light on the camera phone goes off within ~15 s.
3. Background: with the camera on, lock the camera phone and wait 5 minutes: video must keep going.
4. Swipe the camera app away from recents: it should still be listed and Turn on should still work.
5. Restart the camera phone (unlock once if it has a lock screen): it should appear in the viewer list without opening the app.
6. While watching, open another camera app on the camera phone, then leave it: the viewer should reconnect by itself.
7. Flip front/back from the viewer a few times: it must stay on the lens you chose.

## Troubleshooting: "background service is not available"

The camera app's native part (service, boot receiver, Home app) is added during the build by
`tools/prepare_android.sh` -> `tools/camera_background.py` (using `tools/native/*.tmpl`).
In the **Build APKs** log, step "Generate Android project", you should see
`Applying camera background patch...` and several `wrote .../Bridge.kt` lines.
If they are missing, `mobile-cctv/tools` (including `tools/native`) was not fully uploaded.
Note: folders starting with a dot, such as `.github`, are hidden by many file managers and
skipped by drag-and-drop uploads; this project no longer relies on the workflow file for the patch.

## Optional: TURN relay for strict networks

In the Firebase console add a node `config/turn`:

```json
{ "urls": "turn:your.turn.server:3478", "username": "user", "credential": "secret" }
```

Both apps read it on every connection, so no rebuild is required.

## Prototype limitations

- Android only for now.
- If the camera phone has a screen lock, unlock it once after a reboot (Android only sends the boot broadcast then).
- The camera hardware itself is the biggest battery drain; keep the camera phone plugged in.
- Signaling uses 1-second polling over REST, so pairing takes a second or two.
- Presence changes can take up to ~15 seconds to show on the viewer.
- The camera app no longer records clips locally; recording is done from the viewer.
- If the release APK crashes on launch, add `--no-shrink` to `flutter build apk` in the workflow.
- The "DF" logo is a placeholder drawn in code; swap in the real logo asset later.
