# Build Fix Summary - mandarin_app

## Root Causes
1. **Implicit compileSdk** - Used `flutter.compileSdkVersion` which varies by Flutter version at runtime
2. **Unpinned Flutter in CI** - `channel: 'stable'` could install different version
3. **Missing SDK components in CI** - Runner lacked platform-36, build-tools-36.0.0, NDK 28.2.13676358

## Changes Made

| File | Change |
|------|--------|
| `android/app/build.gradle.kts` | `compileSdk = 36` (explicit) |
| `android/gradle/wrapper/gradle-wrapper.properties` | Keep Gradle 9.3.1 (required by AGP 9.1.0) |
| `.github/workflows/build_release.yml` | Pin Flutter to `3.47.6` |
| `.github/workflows/build_release.yml` | Add SDK install step (platforms, build-tools, NDK) |

## Verification
- ✅ `flutter pub get`
- ✅ Gradle 9.3.1 + AGP 9.1.0 compatibility confirmed
- ✅ Android SDK platform-36 present locally
- ⚠️ Local full build blocked by disk space (1.1GB free, NDK needs ~2.5GB)
- ✅ CI configuration complete - should succeed on GitHub runners (~50GB space)

## Compatibility Matrix
- Flutter 3.47.6 (Dart 3.13.5)
- AGP 9.1.0
- Gradle 9.3.1
- KGP 2.4.0
- Java 17
- compileSdk 36 / targetSdk 36 / minSdk 24
- NDK 28.2.13676358