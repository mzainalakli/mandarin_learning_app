# Getting Started

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.47.6 (stable) | This is the version CI uses. `pubspec.yaml` requires Dart `^3.13.5`. |
| Git | any recent | |
| Android toolchain | JDK 17, Android SDK platform 36 | Only for Android builds. |
| Linux desktop toolchain | `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev` | Only for Linux builds. |
| Windows desktop toolchain | Visual Studio with *Desktop development with C++* | Only for Windows builds. |

Verify your setup with `flutter doctor`.

## Get the code and dependencies

```bash
git clone https://github.com/mzainalakli/mandarin_learning_app.git
cd mandarin_learning_app
flutter pub get
```

## Run the app

```bash
flutter run -d linux      # Linux desktop
flutter run -d windows    # Windows desktop
flutter run -d android    # connected device or emulator
```

On first launch the app creates its database and loads the bundled vocabulary (14,868 rows). This happens before the first screen appears, so the very first start takes noticeably longer than later ones.

### Where the database is stored

| Platform | Location |
|---|---|
| Android | The app's private databases directory (sqflite default), file `mandarin.db`. |
| Linux / Windows / macOS | `<current working directory>/.dart_tool/sqflite_common_ffi/databases/mandarin.db` |

On desktop the path is **relative to the directory the process is started from**, because `sqflite_common_ffi` resolves it that way and the app does not override it. If you launch the built executable from different working directories you will get separate databases (each with its own progress, custom words and libraries). Always start it from the same place, or see [Known issues](known-issues.md#desktop-database-path-depends-on-the-working-directory).

To start fresh, delete `mandarin.db`; the next launch re-seeds it.

## Quality checks

```bash
flutter analyze    # static analysis — must report "No issues found!"
flutter test       # 27 unit/widget tests in test/
```

CI runs both before building. The analyzer configuration lives in `analysis_options.yaml` (it includes `flutter_lints` and excludes the platform folders, `build/` and the stray `responsive_ui_template/` folder).

## Build release artifacts

```bash
# Android APK
flutter build apk --release --no-tree-shake-icons

# Linux bundle  (output: build/linux/x64/release/bundle/)
flutter config --enable-linux-desktop
flutter build linux --release

# Windows bundle (output: build\windows\x64\runner\Release\)
flutter config --enable-windows-desktop
flutter build windows --release
```

`--no-tree-shake-icons` is used for the APK build in CI; keep it if you reproduce the CI build locally.

> **Signing:** the Android release build type is currently signed with the **debug** keystore (`android/app/build.gradle.kts` contains a `TODO` for a real signing config). APKs produced this way are fine for side-loading and testing but cannot be published to the Play Store. The application id is still the template default, `com.example.mandarin_app`.

## Platform support

The repository contains scaffolding for Android, iOS, Linux, macOS, Windows and web, but only **Android, Linux and Windows** are built in CI and exercised. `main.dart` initialises the FFI SQLite factory for Linux, Windows and macOS. The web target is not usable: the app relies on `dart:io` and native SQLite.

## Releases

Pushing to the `production` branch triggers [the release workflow](ci-cd.md), which builds all three platforms and publishes a single GitHub Release containing the APK, the Linux zip and the Windows zip.
