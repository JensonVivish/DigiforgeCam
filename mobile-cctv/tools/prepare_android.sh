#!/usr/bin/env bash
# Run inside camera_app/ or viewer_app/ after `flutter create`.
# Adds the permissions WebRTC needs, sets minSdk, and sets the launcher label.
set -euo pipefail
LABEL="${1:-DigiForge}"
MANIFEST=android/app/src/main/AndroidManifest.xml

python3 - "$MANIFEST" "$LABEL" <<'PY'
import re, sys
path, label = sys.argv[1], sys.argv[2]
s = open(path).read()
perms = [
    "INTERNET", "ACCESS_NETWORK_STATE", "CHANGE_NETWORK_STATE",
    "CAMERA", "RECORD_AUDIO", "MODIFY_AUDIO_SETTINGS", "WAKE_LOCK",
]
if "permission.CAMERA" not in s:
    block = "".join(
        f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in perms
    )
    s = s.replace("<application", block + "    <application", 1)
s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)
open(path, "w").write(s)
PY

# flutter_webrtc needs a higher minSdk than Flutter's default.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then sed -i 's/flutter\.minSdkVersion/21/g' "$f"; fi
done

# Keep the screen on while the app is open (native flag, no plugin needed).
python3 "$(dirname "$0")/patch_main_activity.py"

# Camera app only: add the background service, boot receiver and Home-app support.
# Done here (not only in the workflow) so it works with any version of the workflow file.
if grep -q "^name: digiforge_cctv_camera" pubspec.yaml; then
  echo "Applying camera background patch..."
  python3 "$(dirname "$0")/camera_background.py"
fi
