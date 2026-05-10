# Tabora

Tabora is a macOS window switcher MVP inspired by AltTab.
It is intentionally scoped to a practical first slice:

- Global invocation with `Option + Tab`
- A menu bar item for checking current permission status on demand
- A menu bar toggle for `Start at Login`
- A menu bar action for `Check for Updates…` via Sparkle
- Window-level enumeration scoped to the frontmost app
- A centered overlay that shows thumbnails, window titles, app names, and app icons
- Keyboard-driven navigation with graceful fallback when permissions or thumbnails are unavailable

## Install

### Homebrew

```bash
brew install --cask mkusaka/tap/tabora
```

### Manual Download

Download the latest `.zip` from [GitHub Releases](https://github.com/mkusaka/Tabora/releases), extract it, and move `Tabora.app` to `/Applications`.

GitHub Releases and the Homebrew cask are intended to be signed with a Developer ID certificate and notarized by Apple so Gatekeeper can allow normal launch after download.

## Status

The repository already includes the Xcode project, the app target, and the UI test target.
The current MVP is buildable and testable as-is.

## Architecture

The MVP uses a mixed macOS architecture on purpose.

- `SwiftUI`: overlay card UI and lightweight test host UI
- `AppKit`: top-level overlay panel, key handling, activation policy, app lifecycle hooks
- `CoreGraphics`: window enumeration
- `ScreenCaptureKit`: window thumbnail capture on modern macOS SDKs
- `Accessibility API`: best-effort exact window focusing and raising
- `Sparkle`: in-app update checks against a signed appcast feed

Recommended runtime shape:

```text
TaboraApp
├─ AppDelegate
├─ MenuBarController
├─ TaboraRuntime
├─ TaboraLogger
├─ HotkeyManager
├─ PermissionService
├─ WindowCatalogService
├─ ThumbnailService
├─ WindowActivationService
├─ SwitcherState
├─ OverlayWindowController
└─ SwiftUI Views
   ├─ RootHostView
   ├─ SwitcherView
   └─ WindowItemView
```

## Why These Frameworks

- SwiftUI alone is not sufficient for global hotkeys, overlay panel management, or low-level keyboard handling.
- AppKit is the cleanest way to own a key-capable floating panel and bridge lifecycle concerns.
- CoreGraphics is still the most direct API for enumerating user-visible windows.
- ScreenCaptureKit is the practical thumbnail path on modern macOS SDKs where older window-image APIs are no longer available.
- Accessibility is needed for better window-level activation when app activation alone is not precise enough.
- A status item keeps permission visibility available even when no overlay is visible, and key runtime events are printed to stdout for debugging.
- Sparkle provides the native macOS updater UX, while signed GitHub Release ZIPs remain the canonical download artifact.

## Bootstrap

Open [Tabora.xcodeproj](Tabora.xcodeproj) with Xcode 26.3, build the `Tabora` scheme, and run the app.

If you need to recreate the project from scratch in Xcode, the original bootstrap notes are in [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md).

## Tooling

This repository uses `mise` to pin CLI tools for formatting and linting.

```bash
brew install mise
mise trust
mise install
```

## Lint

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
```

## Format

```bash
mise exec -- swiftformat .
```

## Git Hooks

Install the repo-local hooks after `mise install`:

```bash
mise exec -- lefthook install
```

The `pre-commit` hook formats staged Swift files with `swiftformat`, re-stages
any fixes, and then runs `swiftlint` against the staged Swift files.

## Test

```bash
# All tests
xcodebuild -project Tabora.xcodeproj -scheme Tabora -destination 'platform=macOS' test

# Unit tests only
xcodebuild -project Tabora.xcodeproj -scheme Tabora -destination 'platform=macOS' -only-testing:TaboraTests test

# UI tests only
xcodebuild -project Tabora.xcodeproj -scheme Tabora -destination 'platform=macOS' -only-testing:TaboraUITests test
```

## Release Automation

Signed releases use a locally exported `Developer ID Application` certificate together with an App Store Connect API key for `notarytool`.

Required GitHub repository secrets:

- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_DEVELOPER_ID_P12_BASE64`: Base64-encoded `Developer ID Application` certificate exported as `.p12`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`: Password used when exporting the `.p12`
- `APPLE_KEYCHAIN_PASSWORD`: Random password used for the temporary GitHub Actions keychain
- `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`: Base64-encoded App Store Connect API key (`.p8`) used for `notarytool`
- `APPLE_APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APPLE_APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID
- `HOMEBREW_TAP_TOKEN`: GitHub token with permission to dispatch updates to `mkusaka/homebrew-tap`
- `SPARKLE_ED_PRIVATE_KEY`: Sparkle EdDSA private key used to sign release ZIPs for appcast delivery

The release workflow:

- Runs the shared `Test` workflow first
- Archives and exports a `Developer ID` signed app
- Notarizes and staples the app
- Uploads `Tabora.zip` to GitHub Releases for tag pushes
- Dispatches a cask update to `mkusaka/homebrew-tap`
- Signs the release ZIP with Sparkle EdDSA and deploys `appcast.xml` to the `gh-pages` branch

Manual validation runs are supported through `workflow_dispatch`. They require signing secrets but skip GitHub Release creation and Homebrew tap updates.

### How To Cut A Release

1. Merge the release target changes into `main` and confirm the `Test` workflow is green.
2. Create and push a semantic version tag.

```bash
VERSION=0.0.5
git tag "v${VERSION}"
git push origin "v${VERSION}"
```

3. Watch the `Release` workflow that was triggered by the tag push.

```bash
gh run list --workflow Release --limit 5
gh run watch
```

4. Verify that the workflow produced all downstream artifacts.

```bash
gh release view "v${VERSION}"
curl -fsSL https://mkusaka.github.io/Tabora/appcast.xml | rg "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
```

Expected results:

- a signed `Tabora.zip` attached to the GitHub Release
- a cask update dispatch to `mkusaka/homebrew-tap`
- an updated `appcast.xml` on the `gh-pages` branch

The workflow derives the release version from the tag name, so repository files do not need a manual version bump just for release publication.

### How To Run A Validation Build

Use `workflow_dispatch` on the `Release` workflow when you want to validate signing, notarization, and export without publishing a GitHub Release or updating Homebrew / Sparkle delivery.

Dispatch it with a version input, for example:

```bash
gh workflow run Release --field version=0.0.5
gh run list --workflow Release --limit 5
gh run watch
```

The workflow will:

- set `CFBundleShortVersionString` from that version
- derive a numeric `CFBundleVersion` for Sparkle comparisons
- build, sign, notarize, and export the app
- skip GitHub Release creation, Homebrew dispatch, and `gh-pages` appcast deployment

Sparkle compares updates using `CFBundleVersion` / `sparkle:version`, not the human-readable `CFBundleShortVersionString`. This project keeps the visible release version as `0.0.x`, but publishes a numeric Sparkle build version derived from it so upgrades remain monotonic across shipped releases.

For Sparkle to work in production, GitHub Pages must be enabled for this repository and configured to serve from the `gh-pages` branch.

## Task Breakdown

Detailed task decomposition is in [docs/TODO.md](docs/TODO.md).

The tasks are split so the risky platform work is isolated:

- bootstrap and target wiring
- overlay and keyboard routing
- real window catalog
- thumbnail pipeline
- activation fallback
- UI test harness and deterministic fixtures
- polish pass for permission fallback and noisy window filtering

## UI Testing Strategy

The UI tests should validate product behavior, not the host machine state.
That means:

- The app target exposes a UI test mode through launch arguments and environment variables.
- Seeded mock windows are used for deterministic overlay assertions.
- Activation results are recorded back into the app UI so tests can assert confirm/cancel behavior.
- Real global hotkey capture is kept outside UI test scope.

## Known Limitations

- Exact window raising is still best-effort and depends on Accessibility permission plus AX window matching.
- Thumbnail capture for third-party windows depends on Screen Recording permission.
- Multi-display placement is intentionally simple in MVP.
- The initial ordering is front-to-back snapshot based within the frontmost app, not a sophisticated MRU model.
- `Option + Tab` global registration is planned with Carbon hotkeys, while repeated navigation happens in the overlay panel itself.

## Post-MVP

- Settings UI for shortcut remapping and exclusion rules
- Better Space and fullscreen handling
- More accurate MRU ordering
- Mouse interactions and better multi-display placement
- More aggressive noise filtering once real-world samples are available
