# Setup

1. Push the repo to GitHub. The workflow in `.github/workflows/build-apk.yml`
   builds both APKs (Actions tab → latest run → Artifacts).
2. Install the camera APK on the spare phone and the viewer APK on yours.
3. Apply the Firebase rules and (optionally) the TURN relay in
   `CONNECTION_SETUP.md`.
4. Camera phone: open the app, allow camera + microphone. Tap **Show QR** to see
   the pairing code. The code stays the same after restarts.
5. Viewer phone: **Connect** tab → scan the QR, or tap **Enter pairing code**.
   After the first connection, **Reconnect to last camera** appears.

There is no signaling server to deploy: pairing and connection setup run
through Firebase Realtime Database; video goes phone-to-phone.
