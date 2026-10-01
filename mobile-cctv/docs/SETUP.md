# Setup guide

## 1. Signaling server
```
cd signaling_server
npm install
npm start
```
Deploy it publicly (Railway/Render/Fly.io are the quickest) and note the
HTTPS URL — you'll need it in the apps' config.

## 2. Point the apps at your server
Edit both:
- `camera_app/lib/config/app_config.dart`
- `viewer_app/lib/config/app_config.dart`

Set `signalingServerUrl` to your deployed server's URL.

## 3. Get an APK (no local Flutter needed)
Push to GitHub on `main` — the Actions workflow builds both APKs and
attaches them to the workflow run under **Artifacts**.

## 4. Local development (optional, needs Flutter SDK installed)
This repo ships only the Dart source, not the native `android/`/`ios/`
folders (CI generates those). To run locally:
```
cd camera_app
flutter create --platforms=android,ios .
flutter pub get
flutter run
```
Repeat for `viewer_app`. You'll need to re-add the permissions the CI
workflow adds automatically (see `.github/workflows/build-apk.yml` for the
exact lines) to your locally generated `AndroidManifest.xml`.

## 5. Testing pairing
1. Install the camera APK on Device A, viewer APK on Device B.
2. Open the camera app — it shows a QR code + 6-character pairing code.
3. Open the viewer app and scan that QR code.
4. The camera app should show "LIVE" and the viewer should show the feed
   within a few seconds. If it hangs on "Connecting…", see CI_NOTES.md and
   the TURN server note in the root README — NAT traversal is the most
   common real-world failure point for WebRTC apps like this.
