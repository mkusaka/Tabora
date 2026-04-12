# Tabora Xcode Bootstrap

This is the only part expected to be done manually in Xcode.
Once this is done, the repository contents are ready to be wired into the project.

## 1. Create the Project

1. Open Xcode 16.4.
2. `File` -> `New` -> `Project...`
3. Choose `macOS` -> `App`.
4. Use these values:
   - Product Name: `Tabora`
   - Team: your local/default value
   - Organization Identifier: your normal reverse-DNS value
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Testing System: `XCTest`
   - Storage: `None` unless you intentionally want SwiftData
5. Save the project into this repository root: `/Users/masatomokusaka/src/github.com/mkusaka/Tabora`
6. If Xcode asks about Git repository creation, do not create another Git repo.

## 2. Create Targets

Confirm these targets exist:

- `Tabora`
- `TaboraTests`
- `TaboraUITests`

If the template did not create `TaboraUITests`, add it immediately:

1. `File` -> `New` -> `Target...`
2. Choose `UI Testing Bundle`
3. Name it `TaboraUITests`

## 3. Keep the Project Minimal

Do not add extra frameworks yet.
The current scaffold is designed to use only Apple frameworks:

- `SwiftUI`
- `AppKit`
- `ApplicationServices`
- `Carbon`
- `ScreenCaptureKit`
- `XCTest`

## 4. Add Existing Repository Files

After project creation:

1. In Xcode navigator, remove the template `ContentView.swift` if you do not need it.
2. Drag the existing `Tabora/` folder into the `Tabora` target.
3. Drag the existing `TaboraUITests/` folder into the `TaboraUITests` target.
4. Make sure `Copy items if needed` is unchecked if the files are already in place in this repo.
5. Make sure target membership is correct:
   - `Tabora/**` -> `Tabora`
   - `TaboraUITests/**` -> `TaboraUITests`

## 5. Project Settings

Apply these settings before the first run:

- `General` -> `Deployment Info`
  - macOS deployment target: `macOS 15.0` if possible, otherwise keep it consistent with your local baseline
- `Signing & Capabilities`
  - Keep normal local signing
- `Info`
  - For early development, keep `Application is agent (UIElement)` unset
  - After the overlay flow is stable, switch it to `YES` if you want a background utility style app

Reason:

- Leaving the app non-agent at first makes UI testing and debugging much less painful.
- The accessory/agent behavior can be introduced after the overlay and keyboard flow are stable.

## 6. First Build Pass

Before editing anything in Xcode:

1. Build once with the template-only project.
2. Then build again after adding the repository files.
3. Fix any duplicate `@main` or template scene files by removing the template leftovers.

Expected file ownership after wiring:

- `Tabora/App/TaboraApp.swift` should be the only `@main`.

## 7. First Run Pass

Use this order:

1. Run the app target normally
2. Confirm the app launches
3. Confirm the debug host window appears only in UI testing mode
4. Then run the UI test target

## 8. Permissions to Prepare Locally

The real app flow depends on:

- Accessibility permission for better window focus/raise
- Screen Recording permission for third-party window thumbnails

For development:

1. Grant permissions from System Settings when prompted
2. If macOS caches stale permissions, remove and re-add the built app in the relevant privacy pane

## 9. Recommended First Commands After Bootstrap

Run these from the repo root after the Xcode project exists:

```bash
xcodebuild -scheme Tabora -project Tabora.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme TaboraUITests -project Tabora.xcodeproj -destination 'platform=macOS' test
```

If the second command fails because the UI test scheme name differs, use the actual generated scheme name from:

```bash
xcodebuild -list -project Tabora.xcodeproj
```
