#!/usr/bin/env bash
# android/ ios/ 폴더가 없으면 만들고, 앱 이름 · 권한 문구 · 알림 설정을 넣는다.
# 여러 번 돌려도 안전하다. (이미 있는 설정은 건드리지 않는다)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org com.isla0x --project-name roll --platforms android,ios .
  rm -f test/widget_test.dart
fi

python3 - <<'PY'
import re, pathlib

# --- iOS: 표시 이름 + 권한 문구 ---
plist = pathlib.Path("ios/Runner/Info.plist")
if plist.exists():
    s = plist.read_text()
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\1Roll\2", s)
    keys = {
        "NSCameraUsageDescription": "Roll needs the camera to take photos for your film roll.",
        "NSPhotoLibraryAddUsageDescription": "Roll saves developed photos to your photo library.",
    }
    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in keys.items() if f"<key>{k}</key>" not in s
    )
    if "<key>ITSAppUsesNonExemptEncryption</key>" not in s:
        add += "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n"
    if add:
        i = s.rfind("</dict>")
        s = s[:i] + add + s[i:]
    plist.write_text(s)

# --- Android: 표시 이름 + 알림 권한 + 예약 알림 리시버 + 옛 기기 저장 권한 ---
manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
    s = manifest.read_text()
    s = re.sub(r'android:label="[^"]*"', 'android:label="Roll"', s, count=1)
    if "xmlns:tools=" not in s:
        s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    perms = {
        "POST_NOTIFICATIONS": '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        "RECEIVE_BOOT_COMPLETED": '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
        "WRITE_EXTERNAL_STORAGE": ('<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
                                   'android:maxSdkVersion="29" tools:replace="android:maxSdkVersion" />'),
    }
    for key, line in perms.items():
        if key not in s:
            s = s.replace("<application", line + "\n    <application", 1)
    if "ScheduledNotificationReceiver" not in s:
        receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
"""
        i = s.rfind("</application>")
        s = s[:i] + receivers + "    " + s[i:]
    manifest.write_text(s)

# --- Android: Google Play 서명 · API 36 · desugaring 이 들어간 앱 빌드 설정 ---
app_gradle = pathlib.Path("android/app/build.gradle.kts")
if app_gradle.exists() and "android-upload.properties" not in app_gradle.read_text():
    app_gradle.write_text(pathlib.Path("tool/templates/app.build.gradle.kts").read_text())

# --- Android: 오래된 플러그인도 최신 SDK 로 빌드한다 ---
root = pathlib.Path("android/build.gradle.kts")
if root.exists():
    s = root.read_text()
    mark = "// Roll: plugin compileSdk"
    if mark not in s:
        block = mark + """
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null && plugins.hasPlugin("com.android.library")) {
            try {
                android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    .invoke(android, java.lang.Integer.valueOf(36))
            } catch (e: NoSuchMethodException) {
                android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 36)
            }
        }
    }
}

"""
        anchor = "subprojects {\n    project.evaluationDependsOn"
        i = s.find(anchor)
        s = s[:i] + block + s[i:] if i >= 0 else s + "\n" + block
        root.write_text(s)
PY

flutter pub get
dart run flutter_launcher_icons

echo "platform folders ready."
