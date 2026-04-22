# Lilith Mesh integration package

This branch contains the first GitHub-safe mesh package extracted from the merged local build.

## What is included in this package
- `Lilith/MeshWorkspaceView.swift`
- `Lilith/MeshConsole/index.html`
- `Lilith/MeshConsole/styles.css`
- `Lilith/MeshConsole/app.js`

## Why this is packaged this way
The GitHub connector available in this session supports file-level text writes well, but it is not a good path for uploading the full merged ZIP archive directly as a binary asset. Because of that, this branch is being used to push the mesh source package and the exact files needed for the bundled in-app mesh console.

## Next manual wiring step in Xcode
1. Add `Lilith/MeshWorkspaceView.swift` to the Lilith target.
2. Add the full `Lilith/MeshConsole` folder to **Copy Bundle Resources**.
3. Link the new workspace from your existing `WorkspaceShellView` or web workspace hub.
4. Clean build folder and rebuild.

## Intended behavior
The mesh workspace opens a bundled local web UI inside Lilith using `WKWebView`. The UI includes:
- Messages
- Nodes
- Map
- Network
- Settings

## Current status
This package is ready as a source import package. It still needs the existing repo's navigation and Xcode project file to reference it before the app can launch the mesh workspace from the live UI.
