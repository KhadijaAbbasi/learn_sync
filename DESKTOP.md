# Native Windows desktop app

The `windows/` runner builds a native `learnsync.exe`. It shares the responsive
desktop UI and Firebase project with the mobile application.

## Windows requirements

- Install Visual Studio or Visual Studio Build Tools with **Desktop development
  with C++**, the MSVC x64/x86 toolset, CMake tools, and a Windows SDK.
- Free enough disk space on both the system and target drives for Microsoft's
  installer, Flutter's Windows artifacts, and the native build.
- Check `flutter doctor -v` after installing the tools.

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

On this machine, an x64 Release Firebase SDK is prepared under
`D:\DeveloperTools\LEARNsync\FirebaseCppRelease`. To reuse those dependencies
without downloading the full SDK for other architectures and Debug builds, run:

```powershell
.\scripts\run_windows_release.ps1
```

This helper sets the Firebase SDK path only while running the Release app and
restores the previous environment afterward. Debug builds use the normal full
SDK download instead. Once the Release app is built, it can also be launched
directly from its complete output folder without Flutter.

## Windows release

```powershell
flutter build windows --release
```

Launch `build/windows/x64/runner/Release/learnsync.exe`. When sharing the app,
distribute the **whole Release folder**, including `data/`, DLLs and
`flutter_windows.dll`. The executable alone is insufficient. An installer can
package this folder after the first native build is verified.

PDF and PPTX slides use pdfx's Windows-compatible viewer; page changes, jump to
slide and keyboard navigation publish through the same live session. Other
Office formats open in the installed desktop app. Windows Cloud Function calls
use Firebase's callable HTTP protocol and the signed-in user's ID token because
the Flutter Cloud Functions plugin has no Windows implementation. Existing
phone/password accounts can sign in; phone OTP signup/reset requires the mobile
app, while email signup/reset remains available on Windows.

Run `flutter test test/windows_callable_client_test.dart test/desktop_layout_test.dart`
for the protocol and responsive layout checks. The native Release build and
desktop-window startup were verified on this machine. The installed app is at
`D:\Apps\LEARNsync\learnsync.exe`, with Desktop and Start Menu shortcuts.
A real desktop-to-phone lecture still needs end-to-end verification.
Firebase's Windows plugins are documented for local development rather than
production deployments; assess that limitation before distributing a public release.

# Optional desktop browser version

LEARNsync shares its Flutter screens and Firebase backend between Android/iOS
and desktop browsers. The browser target below is separate from the native
Windows build above.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

## Release and preview

```powershell
flutter build web --release
python -m http.server 8080 --directory build/web
```

Open http://localhost:8080. Serve the output over HTTP/HTTPS rather than opening
index.html from the filesystem. Use HTTPS for a hosted release. Firebase Hosting
is configured to serve `build/web` and return `index.html` for application routes.
Deploy only hosting with `firebase deploy --only hosting` after reviewing the
build and selecting the intended Firebase project. No deployment is automatic.

## Desktop behavior

- Permanent sidebar on wide screens; mobile bottom navigation stays available
  on smaller screens. The sidebar scrolls on short laptop windows.
- Courses flow into columns without fixed card heights. Dashboard headers scroll
  with their content on desktop.
- Live lecture slides appear beside course information and attendance from
  1100 logical pixels wide. Smaller windows retain the stacked layout.
- Presenter shortcuts while the slide viewer is focused: Left/Right arrows for
  previous/next, Ctrl+J for Jump to slide. Page changes use the existing live
  session synchronization.
- Browser downloads use the browser's download handling, without local file paths.
- PDF.js loads from jsDelivr before Flutter starts. PDF/PPTX lecture rendering
  requires that CDN to be reachable. Office documents that use the embedded
  Microsoft viewer require a publicly reachable document URL.
- AI practice uses the existing Cloud Function; client `.env` files are not
  bundled. Keep AI provider keys in the backend.

## Verification

```powershell
flutter test test/desktop_layout_test.dart
flutter test --dart-define=CAPTURE_DESKTOP_PREVIEWS=true test/desktop_layout_test.dart
```

The second command writes UI previews to `build/desktop-previews`.
Before a public release, verify real accounts, uploads/downloads, AI practice,
and a teacher-browser/student-phone live lecture using the configured Firebase
project. Add the deployed hostname to Firebase Authentication authorized domains.
Browser focus monitoring cannot pin the device or block other apps, screenshots,
calls, or browser controls.
