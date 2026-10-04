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
3. Tap **Record clip** on either side to save an mp4 (Recordings / Clips tab).
4. Next time, tap **Reconnect** on the Viewer home screen.

## Background mode and start on reboot (camera app)

Built for older phones: Android 5.0 and up, tuned for Android 5 to 10 (Samsung and Realme included).

The camera app runs as an Android foreground service, so the camera keeps streaming with the
screen off, while you use other apps, and after the app is swiped away. A persistent
notification shows `LIVE` / `Standby` and has a **Stop** button (Stop ends everything,
including the camera). If Android kills the process, the service restarts itself and brings the
camera back.

One-time setup on the camera phone (open the **Background mode** card in the app):

1. Open the app once and allow camera and microphone.
2. Leave **Keep running in background** on (default).
3. Tap **Allow** next to **Unrestricted battery** (Android 6+) and **Notifications** if shown.
4. Tap the vendor button and do the manual steps:
   - **Samsung:** Settings > Device care (or Battery) > Battery > App power management
     (or Background usage limits) > add DigiForge Camera to the apps that never sleep.
     Also turn off "Put unused apps to sleep".
   - **Realme:** Settings > App management (or Apps) > DigiForge Camera > turn on Auto launch,
     allow background activity, and set battery usage to unrestricted.
5. Turn on **Start when phone reboots**.

**Battery saver** (on by default): when nobody is watching and the app is not on screen, the camera
hardware is switched off after 30 seconds. It wakes up when a viewer connects (adds a second or
two to the first connection). Turn it off in the card if you want the camera always on.

The camera captures at 640x480, 15 fps to keep older phones, battery and mobile data happy.
Change `kCaptureWidth/Height/Fps` in `camera_app/lib/camera_service.dart` for more quality.

How start-on-reboot works:

- **Android 10 and older:** the service starts straight from the boot broadcast and brings the camera
  up with nothing on screen. If the phone has a screen lock, Android only sends the boot broadcast
  after the first unlock; with no lock screen it is fully hands-free.
- **Android 11 and newer:** Android forbids starting a camera service from the boot broadcast, so the
  app opens itself (needs "Display over other apps") and then moves to the background; a
  "Tap to start the camera after reboot" notification is left as a fallback.

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
- If the release APK crashes on launch, add `--no-shrink` to `flutter build apk` in the workflow.
- The "DF" logo is a placeholder drawn in code; swap in the real logo asset later.
