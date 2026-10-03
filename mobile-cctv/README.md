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

## Optional: TURN relay for strict networks

In the Firebase console add a node `config/turn`:

```json
{ "urls": "turn:your.turn.server:3478", "username": "user", "credential": "secret" }
```

Both apps read it on every connection, so no rebuild is required.

## Prototype limitations

- The camera must stay in the foreground (the screen is kept on automatically while the app is open; no background service yet).
- Android only for now.
- Signaling uses 1-second polling over REST, so pairing takes a second or two.
- Presence changes can take up to ~15 seconds to show on the viewer.
- If the release APK crashes on launch, add `--no-shrink` to `flutter build apk` in the workflow.
- The "DF" logo is a placeholder drawn in code; swap in the real logo asset later.
