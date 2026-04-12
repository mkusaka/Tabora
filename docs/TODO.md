# Tabora MVP TODO

This file decomposes the MVP into implementable issues with explicit acceptance criteria.

## Phase 0: Xcode Bootstrap

- [ ] Create `Tabora.xcodeproj` with `Tabora`, `TaboraTests`, and `TaboraUITests`
- [ ] Add the repository `Tabora/` files to the app target
- [ ] Add the repository `TaboraUITests/` files to the UI test target
- [ ] Remove template duplicate entrypoints so `Tabora/App/TaboraApp.swift` is the only `@main`
- [ ] Confirm `xcodebuild -list -project Tabora.xcodeproj` shows usable schemes

Acceptance criteria:

- The project opens cleanly in Xcode
- The app target resolves all repository files
- The UI test target resolves all repository test files

## Phase 1: App Skeleton and Lifecycle

- [ ] Use `AppDelegate` through `@NSApplicationDelegateAdaptor`
- [ ] Create `TaboraRuntime` as the root composition point
- [ ] Keep normal runs in utility/accessory mode
- [ ] Keep UI tests in a visible host-window mode
- [ ] Expose a deterministic UI test launch path

Acceptance criteria:

- The app launches without showing the production overlay immediately
- UI testing mode can launch into a deterministic host view

## Phase 2: Overlay Shell

- [ ] Add a key-capable `NSPanel` subclass for the switcher overlay
- [ ] Host `SwitcherView` in AppKit through `NSHostingController`
- [ ] Center the overlay on the active screen
- [ ] Keep the panel above normal windows
- [ ] Handle `Tab`, `Shift + Tab`, `Esc`, and confirm keys inside the panel

Acceptance criteria:

- The overlay appears centered
- Keyboard focus stays in the overlay while it is visible
- Cancel and confirm dismiss the overlay reliably

## Phase 3: Window Data and Filtering

- [ ] Enumerate on-screen windows through `CGWindowListCopyWindowInfo`
- [ ] Extract `window id`, `pid`, `app name`, `title`, `bounds`, and `layer`
- [ ] Resolve bundle identifier and app icon from `NSRunningApplication`
- [ ] Filter out obvious non-user-facing windows
- [ ] Exclude Tabora itself from the candidate list

Acceptance criteria:

- The window list is window-level, not app-level
- Tiny, transparent, or obvious system noise windows are mostly absent

## Phase 4: Thumbnail Pipeline

- [ ] Capture per-window preview images through ScreenCaptureKit
- [ ] Load thumbnails asynchronously after the overlay is shown
- [ ] Keep placeholder layout stable before thumbnails arrive
- [ ] Allow per-item thumbnail failure without breaking the overlay

Acceptance criteria:

- At least some third-party windows show real previews when permissions allow
- Missing thumbnails fall back to placeholders without layout collapse

## Phase 5: Activation

- [ ] Activate the target app on confirm
- [ ] Try to match the selected window via Accessibility
- [ ] Raise or focus the best matching AX window
- [ ] Fall back to app-only activation if AX matching fails

Acceptance criteria:

- Confirm at least activates the target app
- With Accessibility permission granted, exact window focus works for common apps often enough to be practical

## Phase 6: Global Shortcut

- [ ] Register `Option + Tab` as a global hotkey
- [ ] On first invoke, snapshot windows and show the overlay
- [ ] Advance selection once on initial presentation when multiple windows exist
- [ ] Confirm selection when the modifier key is released

Acceptance criteria:

- `Option + Tab` works when Tabora is not frontmost
- Releasing `Option` confirms the currently selected window

## Phase 7: Permissions and Debuggability

- [ ] Surface screen-capture fallback messaging when thumbnails are unavailable
- [ ] Surface Accessibility fallback messaging when exact focus may degrade
- [ ] Keep permission-dependent logic isolated in one service
- [ ] Avoid crashes when permissions are missing

Acceptance criteria:

- The app remains usable even when one or both permissions are missing
- Permission-related failures are visible and debuggable

## Phase 8: UI Test Harness

- [ ] Add launch-argument based UI test mode
- [ ] Seed deterministic mock windows from JSON launch environment
- [ ] Add mock thumbnail service with success and failure cases
- [ ] Add mock activation service that records the selected result into visible UI

Acceptance criteria:

- UI tests do not depend on the host machine having specific third-party windows open
- UI tests can assert confirm/cancel behavior deterministically

## Phase 9: UI Tests

- [ ] Verify seeded overlay cards render title, app name, icon, and thumbnail state
- [ ] Verify missing thumbnails show placeholders without losing text
- [ ] Verify empty-title windows remain understandable through app-name fallback
- [ ] Verify initial presentation selects the next candidate
- [ ] Verify `Tab` cycles forward
- [ ] Verify `Shift + Tab` cycles backward
- [ ] Verify `Esc` cancels without activation
- [ ] Verify confirm records the selected window
- [ ] Verify permission warning text appears in degraded modes

Acceptance criteria:

- UI tests cover the main interaction loop end to end
- The suite remains deterministic across machines

## Phase 10: Final Verification

- [ ] Run app build from CLI
- [ ] Run UI test suite from CLI
- [ ] Manually verify real global hotkey behavior
- [ ] Manually verify thumbnail behavior with and without Screen Recording permission
- [ ] Manually verify activation behavior with and without Accessibility permission

Acceptance criteria:

- CLI build passes
- UI tests pass
- Manual verification notes are captured in README or PR notes
