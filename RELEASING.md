# Releasing The Squeeze

This checklist prepares and publishes a GitHub release from `main`.

## 1. Verify metadata and documentation

- `CFBundleShortVersionString` in `Resources/Info.plist` matches the release version.
- `CFBundleVersion` is greater than the previously distributed build.
- `README.md`, `CHANGELOG.md`, `PRIVACY.md`, `SECURITY.md`, and `RELEASE_NOTES.md` describe the shipped behavior.
- The working tree contains no unrelated changes.

For v0.0.3, the marketing version is `0.0.3` and the bundle build is `9`.

## 2. Build and verify

```sh
./scripts/build-app.sh release
codesign --verify --deep --strict "dist/The Squeeze.app"
plutil -extract CFBundleShortVersionString raw "dist/The Squeeze.app/Contents/Info.plist"
```

## 3. Create release artifacts

```sh
cd dist
ditto -c -k --sequesterRsrc --keepParent "The Squeeze.app" "The-Squeeze-v0.0.3.zip"
shasum -a 256 "The-Squeeze-v0.0.3.zip" > "The-Squeeze-v0.0.3.zip.sha256"
shasum -a 256 -c "The-Squeeze-v0.0.3.zip.sha256"
unzip -t "The-Squeeze-v0.0.3.zip"
cd ..
```

## 4. Commit, tag, and push

Review `git diff` before running these commands:

```sh
git add -A
git commit -m "Release v0.0.3"
git tag -a v0.0.3 -m "The Squeeze v0.0.3"
git push origin main
git push origin v0.0.3
```

## 5. Create the GitHub release

With GitHub CLI installed and authenticated:

```sh
gh release create v0.0.3 \
  "dist/The-Squeeze-v0.0.3.zip" \
  "dist/The-Squeeze-v0.0.3.zip.sha256" \
  --title "The Squeeze v0.0.3" \
  --notes-file RELEASE_NOTES.md
```

Confirm that the release page contains both artifacts, the expected checksum, and installation instructions before announcing it.
