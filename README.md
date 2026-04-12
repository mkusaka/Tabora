# Tabora

Tabora is a macOS window switcher MVP inspired by AltTab.
It is intentionally scoped to a practical first slice:

- Global invocation with `Option + Tab`
- A menu bar item for checking current permission status on demand
- A menu bar toggle for `Start at Login`
- Window-level enumeration instead of app-level switching
- A centered overlay that shows thumbnails, window titles, app names, and app icons
- Keyboard-driven navigation with graceful fallback when permissions or thumbnails are unavailable

## Status

This repository is still in bootstrap phase.
The first Xcode project creation step is expected to be done manually in Xcode.
Everything else in this repository is structured so it can be dropped into that project immediately after bootstrap.

## Architecture

The MVP uses a mixed macOS architecture on purpose.

- `SwiftUI`: overlay card UI and lightweight test host UI
- `AppKit`: top-level overlay panel, key handling, activation policy, app lifecycle hooks
- `CoreGraphics`: window enumeration
- `ScreenCaptureKit`: window thumbnail capture on modern macOS SDKs
- `Accessibility API`: best-effort exact window focusing and raising

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

## Bootstrap

Detailed bootstrap instructions are in [docs/BOOTSTRAP.md](/Users/masatomokusaka/src/github.com/mkusaka/Tabora/docs/BOOTSTRAP.md).

The short version:

1. Create a new Xcode `macOS App` named `Tabora` with `SwiftUI` and `Swift`.
2. Keep the project inside this repository root.
3. Add the existing `Tabora/` and `TaboraUITests/` folders to the project after creation.
4. Wire the files to the `Tabora` and `TaboraUITests` targets.
5. Enable Accessibility and Screen Recording related usage/testing flow locally.

## Task Breakdown

Detailed task decomposition is in [docs/TODO.md](/Users/masatomokusaka/src/github.com/mkusaka/Tabora/docs/TODO.md).

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
- The initial ordering is front-to-back snapshot based, not a sophisticated MRU model.
- `Option + Tab` global registration is planned with Carbon hotkeys, while repeated navigation happens in the overlay panel itself.

## Post-MVP

- Settings UI for shortcut remapping and exclusion rules
- Better Space and fullscreen handling
- More accurate MRU ordering
- Mouse interactions and better multi-display placement
- More aggressive noise filtering once real-world samples are available
