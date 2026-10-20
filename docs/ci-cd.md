# CI/CD

The pipeline is a single GitHub Actions workflow, [`.github/workflows/build_release.yml`](../.github/workflows/build_release.yml). It builds Android, Linux and Windows and publishes **one** GitHub Release containing all three artifacts.

## Triggers

| Trigger | Effect |
|---|---|
| `push` to the `production` branch | Full build and release |
| `workflow_dispatch` | Same, started manually from the Actions tab |

A `concurrency` group (`build-release-<ref>`) cancels an in-progress run when a newer push to the same ref arrives.

## Jobs

```
build-linux-android (ubuntu-latest) ─┐
                                     ├─► release (ubuntu-latest) → GitHub Release
build-windows (windows-latest) ──────┘
```

### `build-linux-android`

1. Checkout (with submodules), set up JDK 17 (Zulu, Gradle cache) and Flutter 3.47.6 (cached).
2. Accept Android licences and install `platforms;android-36`, `build-tools;36.0.0`, `ndk;28.2.13676358`.
3. Install Linux build dependencies: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev`.
4. `flutter pub get`
5. **`flutter analyze`** — the quality gate; any finding, including `info`, fails the job.
6. **`flutter test`**
7. `flutter clean`
8. `flutter build apk --release --no-tree-shake-icons`
9. `flutter build linux --release`, then zip the bundle to `mandarin_app-linux-x64.zip`.
10. Upload artifacts `mandarin_app-android` (`app-release.apk`) and `mandarin_app-linux-x64`.

### `build-windows`

1. Checkout, set up Flutter 3.47.6 (stable, cached), enable the Windows desktop target.
2. `flutter pub get`, `flutter build windows --release`.
3. Zip `build\windows\x64\runner\Release\*` to `mandarin_app-windows-x64.zip` with PowerShell `Compress-Archive`.
4. Upload artifact `mandarin_app-windows-x64`.

Analysis and tests run once, in the Linux job; they are platform-independent.

### `release`

Runs only if **both** build jobs succeeded (`needs`). It has `contents: write` permission, which is what allows it to create a release.

1. Download all artifacts into `dist/` (`merge-multiple: true` flattens them).
2. Compute one tag, `v1.0.<UTC timestamp>` (format `YYYYMMDDHHMMSS`), and expose it as `TAG_NAME`.
3. Create the release with `softprops/action-gh-release@v2`, targeting the triggering commit, and attach:
   - `dist/app-release.apk`
   - `dist/mandarin_app-linux-x64.zip`
   - `dist/mandarin_app-windows-x64.zip`

Because the tag is a timestamp, every run creates a new release; nothing is overwritten. If any platform fails, no release (and no partial release) is created.

Artifacts are also kept as workflow artifacts for **7 days** (`retention-days: 7`), independent of the release.

## Required repository settings

- The `release` job declares `permissions: contents: write` itself, so the repository's default workflow permission can stay read-only. An organisation policy that forbids write access for workflows would still block it.
- No secrets are needed beyond the automatic `GITHUB_TOKEN`.

## Shell differences (why steps specify `shell`)

`windows-latest` runners use PowerShell by default, while `ubuntu-latest` uses bash. Bash-only syntax such as `$(date +'%Y%m%d%H%M%S')` or `>> $GITHUB_ENV` fails on Windows. The release tag step therefore lives in the Ubuntu `release` job, and the one Windows step that needs a shell (`Zip Release`) sets `shell: pwsh` explicitly. If you add a Windows step that sets environment variables, use:

```powershell
"NAME=value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
```

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `build-linux-android` fails at *Analyze* with `N issues found` | Run `flutter analyze` locally and fix every finding; CI treats `info` lints as failures. |
| Windows step fails with `date` not recognised | Bash syntax in a PowerShell step — set `shell: bash` or use the PowerShell equivalent. |
| `release` job: *Resource not accessible by integration* | The token lacks `contents: write`; check repository workflow permissions. |
| Android build cannot find an SDK component | Update the `sdkmanager` line to the versions Gradle asks for. |
| Release exists but lacks one file | Artifact name or path in the `files:` block does not match the uploaded name; check the **Download All Artifacts** step output. |

## Limitations

- The APK is signed with the debug key (see [Getting started](getting-started.md#build-release-artifacts)) and uses the template application id, so it is suitable for testing and side-loading, not for store distribution.
- macOS and iOS are not built.
- Version numbers in release tags (`v1.0.<timestamp>`) are independent of `version:` in `pubspec.yaml`.
