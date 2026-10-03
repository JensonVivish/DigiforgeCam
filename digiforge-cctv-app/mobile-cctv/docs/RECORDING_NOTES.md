# Recording feature — implementation notes

Both apps record locally using `flutter_webrtc`'s built-in `MediaRecorder`
class, which records a `MediaStreamTrack` directly to an mp4 file:

```dart
final recorder = MediaRecorder();
await recorder.start(filePath, videoTrack: track);
...
await recorder.stop();
```

- **Camera app** records its own local video track — this works independent
  of whether a viewer is connected, so it behaves like real CCTV local
  storage.
- **Viewer app** records the *remote* track it's currently receiving — i.e.
  "save a copy of what I'm watching right now."

Recordings save to each app's private app-storage folder
(`recordings/` on the camera app, `clips/` on the viewer app) — no extra
storage permission needed on modern Android.

## One thing to check on first build

`MediaRecorder`'s exact parameter names have shifted slightly across
`flutter_webrtc` versions over time. This code was written against the
documented API for `^0.11.7`, matching the plugin's own example app pattern,
but wasn't compiled/run here (no local Flutter/Android SDK — see the root
README). If `flutter analyze` or the build flags an issue in
`recording_service.dart` in either app, it's almost certainly a
`MediaRecorder.start()` parameter name mismatch for your resolved plugin
version — check `flutter_webrtc`'s example app
(`example/lib/src/call_sample/call_sample.dart` in the plugin's GitHub repo)
for the exact current signature and adjust the one `_recorder!.start(...)`
call accordingly. Everything else in the recording flow (file paths,
listing, playback) doesn't depend on that API and needs no changes.
