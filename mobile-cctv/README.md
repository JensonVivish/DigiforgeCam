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

1. Open **DigiForge Camera** on the spare phone, allow camera + microphone, plug it in and leave the app open.
   It shows a permanent 6-character code and a QR.
2. Open **DigiForge Viewer** on your phone, tap **Scan QR code** (or type the code), and you are live.
3. On the viewer, tap **Record clip** to save an mp4 (Clips tab). Use the flip button to switch cameras.
4. Next time, tap **Reconnect** on the Viewer home screen.

## Camera app: background, reboot, permissions

Built for older phones: Android 5.0 and up, tuned for Android 5 to 10 (Samsung and Realme included).
There are no switches. On first launch the app asks for everything in one go (**Allow all**):
camera and microphone, notifications (Android 13+), "keep running in background" (battery),
"display over other apps" (Android 11+ only) and, on Samsung/Realme, the vendor auto-start screen.

Then it just works:

- It runs as a foreground service, so the camera keeps streaming with the screen off, while you use
  other apps, and after the app is swiped away. The notification shows LIVE / Standby; its **Stop**
  button ends everything.
- If Android kills the process, the service restarts and brings the camera back.
- **Start after reboot:** on Android 10 and older the service starts straight from the boot broadcast
  and brings the camera up with nothing on screen (with a screen lock, Android only sends the boot
  broadcast after the first unlock). On Android 11+ the app opens itself and moves to the background.
- **Samsung:** also add DigiForge Camera to the apps that never sleep (Device care / Battery > App power management).
  **Realme:** turn on Auto launch and allow background activity (App management). Android does not let
  apps flip these switches themselves; the Allow-all step opens the right screen.
- **Self-healing:** if the video freezes (the camera silently stalls on some phones), the camera
  detects the missing frames within ~20 s, restarts itself, and the viewer reconnects automatically.
  The viewer also reconnects by itself if the picture freezes for ~15 s.

**Front and back camera:** the camera app has a flip button on its preview, and the viewer has the same
button on the live video. Flipping from the viewer is sent to the camera over the peer-to-peer
connection. Old phones cannot open both cameras at the same time, so it switches rather than showing both at once.

The camera captures at 640x480, 15 fps to keep older phones, battery and mobile data happy.
Change `kCaptureWidth/Height/Fps` in `camera_app/lib/camera_service.dart` for more quality.
The camera always stays on while the service runs, so keep the camera phone plugged in.

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
