# BirdNET Live — Release Process

End-to-end checklist for cutting a Play Store release. Lives outside the
build folder on purpose — every step here is something a human runs by
hand once per release, not part of normal development.

## 1. Pre-flight

- [ ] All target features merged into `dev` and the working tree is clean.
- [ ] `pubspec.yaml` version bumped (e.g. `0.11.4+114` → `0.11.5+115`).
      Build number tracks the patch version.
- [ ] `dart dev/sync_version.dart` propagated the new number to the
      README badge / any other generated locations.
- [ ] `CHANGELOG.md` has a new top entry with date + bullet list.
- [ ] `flutter analyze` is clean.
- [ ] `flutter test` passes.
- [ ] User docs under `docs/user/*.md` describe any new visible setting
      (intuition, not implementation).

## 2. Build the signed bundle

The script `dev/build_release.dart` automates the next two steps. Run:

```pwsh
dart dev/build_release.dart
```

Under the hood that is equivalent to:

```pwsh
flutter build appbundle --release `
  --obfuscate --split-debug-info=build/symbols/<version>
```

Important Windows quirk: the Java toolchain prints obsolete-options
warnings that cause `javac` to return exit code 1 even when Gradle
succeeds. **Don't trust the exit code on its own** — verify by
checking that the line `✓ Built build/app/outputs/bundle/release/app-release.aab`
appears in stdout, or that the AAB exists on disk.

The signing key is read from `android/key.properties`. That file is
not in version control; restore it from the team password vault before
the first release on a new machine.

## 3. Collect release artifacts

`dev/build_release.dart` copies the following into
`release/V<version>/`:

| File                           | Source                                                     | Used for |
| ------------------------------ | ---------------------------------------------------------- | -------- |
| `BirdNET_Live_V<version>.aab`  | `build/app/outputs/bundle/release/app-release.aab`         | Play Console upload |
| `mapping.txt`                  | `build/app/outputs/mapping/release/mapping.txt`            | Play Console → upload for de-obfuscated crash reports |
| `symbols/`                     | `build/symbols/<version>/`                                 | Play Console → optional, for native crash symbolication |
| `release_notes.txt` (template) | seeded from the latest CHANGELOG entry                     | Play Console "What's new" — split per locale |

The `release/` folder is git-ignored on purpose (binaries are large).
This `RELEASE.md` is exempted via `release/.gitignore`.

## 4. Release notes

The Play Console accepts a single text file with one block per locale,
each ≤ 500 characters. Format:

```
<en-US>
What's new in this version, in plain language.
• bullet
• bullet
</en-US>

<de-DE>
…
</de-DE>
```

Locale order this app ships translations for:
`en-US, de-DE, es-ES, fr-FR, it-IT, pt-PT, cs-CZ`.

`dev/build_release.dart` stubs `release_notes.txt` from the latest
CHANGELOG bullets in English. Translation is still a manual step —
edit the file in place before uploading.

## 5. Upload to Play Console

1. Open the **Production** track (or **Internal testing** for a soft
   launch first).
2. Create a new release.
3. Upload `BirdNET_Live_V<version>.aab`.
4. Under "App bundle explorer" → upload `mapping.txt` for the new
   bundle so Play can de-obfuscate ANRs and crashes.
5. Optionally upload the contents of `symbols/` for native crash
   symbolication (ONNX Runtime).
6. Paste each locale block from `release_notes.txt` into the matching
   "What's new" field.
7. Review → roll out (start at 20–50 % staged rollout for any user-
   facing change).

## 6. Post-release

- [ ] Tag the commit on `dev`: `git tag v<version> && git push --tags`.
- [ ] Merge `dev` → `main` once the rollout is at 100 % and crash
      rate is healthy.
- [ ] Update `dev/PROGRESS.md` with the release date and any
      observations from staged-rollout feedback.

---

*Source-of-truth files for the version itself:*
- `pubspec.yaml` — `version: <X.Y.Z>+<build>`
- `README.md` badge — synced from pubspec by `dev/sync_version.dart`
