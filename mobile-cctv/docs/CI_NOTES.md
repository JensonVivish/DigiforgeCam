# CI build notes

The GitHub Actions workflow pins Flutter `3.24.0 (stable)` and runs
`flutter create --platforms=android` inside each app folder to generate the
native Android project before building, then patches in the permissions and
app label with `sed`.

This is a solid, commonly-used approach, but Flutter/Gradle/Android plugin
versions do shift over time, so if the very first CI run fails, check for:

- **Gradle/AGP version mismatch** — shows up as a Gradle sync error. Usually
  fixed by bumping the pinned `flutter-version` in `build-apk.yml` to a newer
  stable release.
- **minSdkVersion conflicts** — `flutter_webrtc` needs minSdkVersion 24+.
  The workflow already patches this in `android/app/build.gradle`; if the
  Flutter version generates a different file layout (e.g. Kotlin DSL
  `build.gradle.kts` instead of Groovy), the `sed` command won't match and
  you'll need to edit the equivalent line by hand.
- **Manifest merger conflicts** — if a plugin's own manifest declares a
  permission or attribute that conflicts with what's patched in, Gradle will
  report exactly which line/plugin is responsible.

None of these are unusual for a first Flutter+WebRTC CI build — they're
normal one-time fixes, not signs the architecture is wrong.
