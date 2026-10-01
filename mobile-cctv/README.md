# DigiforgeDynamics CCTV

Turn a spare phone into a live security camera, watched from another phone —
built by DigiforgeDynamics.

## Architecture

```
Camera app ──▶ Firebase Realtime Database ──▶ Viewer app
                  (signaling only)
                        │
                        ▼
              WebRTC peer-to-peer
              (live video/audio — Firebase never sees it)
```

- **No server to deploy.** Signaling runs through your Firebase project (free, Google's infrastructure, always on).
- **Video is peer-to-peer.** Once paired, the stream goes directly between the two devices — Firebase is not involved.

## Repo structure

```
mobile-cctv/
├── camera_app/          # Flutter — the camera device
├── viewer_app/          # Flutter — the watching device
├── .github/workflows/   # CI that builds real APKs on every push
└── docs/
```

## Getting APKs

Push this repo to GitHub (`main` branch) → go to **Actions** tab → wait ~3 min → open the run → **Artifacts** → download both APKs.

No local Flutter SDK needed.

## Firebase is already configured

Firebase credentials are already in `lib/config/app_config.dart` in both apps — no additional setup needed to build and run.

## Before publishing to the Play Store

- Change Firebase Realtime Database rules from Test mode to authenticated access
- Add a privacy policy (see `docs/PRIVACY_POLICY_TEMPLATE.md`)
- Frame the app as a self-owned home security tool in your store listing

## Features
- 📹 Live WebRTC video streaming between two phones
- 🔗 QR code pairing — no manual IP or URL entry
- ⏺ Local recording on both camera and viewer devices
- 🌙 Wakelock — camera screen stays on while monitoring
- 🎨 DigiforgeDynamics dark theme with cyan accent
