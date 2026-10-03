# Connection setup (Firebase rules + optional TURN relay)

## 1. Firebase Realtime Database rules  (do this once — important)

A database created in "test mode" stops accepting reads/writes about **30 days
after creation**. When that happens the apps silently stop pairing.
Replace the rules now:

Firebase console → Build → Realtime Database → **Rules** tab → paste → **Publish**

```json
{
  "rules": {
    "config":   { ".read": true, ".write": false },
    "sessions": { "$code": { ".read": true, ".write": true } }
  }
}
```

- Nobody can list all sessions; a client must already know a camera's code.
- Anyone who knows a code can view that camera, so keep codes private and use
  "Generate a new code" on the camera if one leaks. Stronger protection later:
  Firebase Authentication + per-user rules.

## 2. TURN relay (only needed if some networks fail to connect)

Most connections work with the built-in free STUN servers. Some mobile
networks (carrier-grade NAT) block direct phone-to-phone connections; those
need a relay. The apps load relay servers from Firebase, so **no credentials
go into the code or GitHub**, and you can change provider without rebuilding.

Provider options (checked October 2026):
- **ExpressTURN** — free tier advertised as 1 TB/month, static username/password.
- **Cloudflare Realtime TURN** — first 1,000 GB/month free, but credentials are
  short-lived and need a small backend to mint them (not covered here).
- **Xirsys** — no card, but only 500 MB/month TURN on the free tier.

Using ExpressTURN (or any provider with a static username/password):

1. Create the account, copy your TURN username, password and server host(s)
   from its dashboard.
2. Firebase console → Realtime Database → **Data** tab → hover the root →
   **+** → name `config` → inside it add `ice_servers`, or use the ⋮ menu →
   **Import JSON** with:

```json
{
  "config": {
    "ice_servers": [
      {
        "urls": [
          "turn:YOUR-TURN-HOST:3478?transport=udp",
          "turn:YOUR-TURN-HOST:3478?transport=tcp",
          "turns:YOUR-TURN-HOST:443?transport=tcp"
        ],
        "username": "YOUR-USERNAME",
        "credential": "YOUR-PASSWORD"
      }
    ]
  }
}
```

3. Close and reopen both apps (they read this when a connection starts).

If TURN is configured, the bar at the bottom of the viewer shows `ICE:
Connected` once the relay or a direct path is up.

## 3. What the status text means

Camera app (bottom panel): `Waiting for viewer…` → `Viewer connecting…` →
`Live — viewer connected`.

Viewer app: `Checking pairing code…` → `Connecting to camera…` →
`Negotiating connection…` → `Live`. If the link drops the viewer keeps
retrying on its own (2s, 4s, 6s … up to every 15s) and never gives up.
