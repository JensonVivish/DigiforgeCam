"""Adds background mode + start-on-boot to the generated camera Android project.
Run inside camera_app/ after `flutter create` (see build-apks.yml)."""
import glob
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(os.path.join(here, "native")):
    sys.exit("tools/native is missing - upload the whole mobile-cctv/tools folder")
acts = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
if not acts:
    sys.exit("MainActivity.kt not found - run `flutter create` first")
kdir = os.path.dirname(acts[0])
pkg = re.search(r"^package\s+(\S+)", open(acts[0]).read(), re.M).group(1)

templates = {
    "MainActivity.kt": "MainActivity.kt.tmpl",
    "EngineHolder.kt": "EngineHolder.kt.tmpl",
    "Bridge.kt": "Bridge.kt.tmpl",
    "CameraForegroundService.kt": "CameraForegroundService.kt.tmpl",
    "BootReceiver.kt": "BootReceiver.kt.tmpl",
    "LaunchGateActivity.kt": "LaunchGateActivity.kt.tmpl",
}
for out_name, tmpl in templates.items():
    src = open(os.path.join(here, "native", tmpl)).read().replace("__PKG__", pkg)
    open(os.path.join(kdir, out_name), "w").write(src)
    print("wrote", os.path.join(kdir, out_name))

mpath = "android/app/src/main/AndroidManifest.xml"
m = open(mpath).read()


perms = [
    "FOREGROUND_SERVICE",
    "FOREGROUND_SERVICE_CAMERA",
    "FOREGROUND_SERVICE_MICROPHONE",
    "RECEIVE_BOOT_COMPLETED",
    "POST_NOTIFICATIONS",
    "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "SYSTEM_ALERT_WINDOW",
    "WAKE_LOCK",
]
if "FOREGROUND_SERVICE_CAMERA" not in m:
    block = "".join(
        '    <uses-permission android:name="android.permission.%s"/>\n' % p
        for p in perms
        if ("permission." + p + '"') not in m
    )
    m = m.replace("<application", block + "    <application", 1)

if ".CameraForegroundService" not in m:
    components = (
        '        <service\n'
        '            android:name=".CameraForegroundService"\n'
        '            android:exported="false"\n'
        '            android:foregroundServiceType="camera|microphone" />\n'
        '        <receiver\n'
        '            android:name=".BootReceiver"\n'
        '            android:enabled="true"\n'
        '            android:exported="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    m = m.replace("</application>", components + "    </application>", 1)

# The invisible gate becomes the only launcher icon; MainActivity is the setup screen.
import re as _re
if ".LaunchGateActivity" not in m:
    m, n = _re.subn(
        r'\s*<intent-filter>\s*<action android:name="android\.intent\.action\.MAIN"\s*/>\s*'
        r'<category android:name="android\.intent\.category\.LAUNCHER"\s*/>\s*</intent-filter>',
        '', m, count=1)
    if n != 1:
        print("WARNING: could not remove the LAUNCHER filter from MainActivity")
    gate = (
        '        <activity\n'
        '            android:name=".LaunchGateActivity"\n'
        '            android:exported="true"\n'
        '            android:theme="@android:style/Theme.NoDisplay"\n'
        '            android:excludeFromRecents="true"\n'
        '            android:noHistory="true"\n'
        '            android:taskAffinity="">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.MAIN" />\n'
        '                <category android:name="android.intent.category.LAUNCHER" />\n'
        '            </intent-filter>\n'
        '        </activity>\n'
    )
    m = m.replace("</application>", gate + "    </application>", 1)

open(mpath, "w").write(m)
print("manifest patched")
