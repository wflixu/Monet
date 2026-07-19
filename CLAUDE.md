# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iMonet is a macOS image viewer application built with SwiftUI, focused on efficient image viewing and navigation with keyboard shortcuts and mouse interactions. It supports static images (PNG, JPEG, WebP) and animated formats (GIF, APNG, WebP) with frame-accurate playback — all using zero external dependencies.

## Build and Run

```bash
swift run                    # Build and run the app (debug, no .app bundle)
swift test                   # Run tests
xcodebuild -scheme iMonet -configuration Release -derivedDataPath build -destination "platform=macOS,arch=arm64" ARCHS=arm64 ENABLE_HARDENED_RUNTIME=YES build  # Release build with .app bundle (for "Open With" testing)
```

## Project Structure

The codebase follows a modular SwiftUI architecture:

- **iMonetApp.swift** - App entry point with `@main`, defines scenes (main window, settings) and AppDelegate
- **AppState.swift** - Global application state (`@MainActor class`), manages image URLs, permissions, settings
- **ContentView.swift** - Main layout with thumbnail sidebar, toolbar, chrome auto-hide, rotation, delete
- **Animator/**:
  - **ImageAnimator.swift** - Decodes animated image frames (GIF/APNG/WebP) via `CGImageSource`, drives playback with `Timer`
- **Views/**:
  - **ImagePreviewView.swift** - Image display with keyboard event monitoring, animated image detection
  - **ZoomableImageView.swift** - Custom `NSView` (`iMonetImageView`) with zoom/pan, supports both `NSImage` and animated `CGImage`
  - **ToolBarView.swift** - Bottom toolbar with navigation controls (note spelling: `ToolBarView`, not `ToolbarView`)
  - **ThumbnailSidebar.swift** - Left thumbnail strip for quick navigation
  - **ImageThumbnailView.swift** - Individual thumbnail rendering
  - **ImageInfoPanel.swift** - Right-side info panel (pixel size, file size, format, date)
- **Shared/**:
  - **AppLogger.swift** - `@AppLog` property wrapper for logging
  - **Util.swift** - `ObjectAssociation` for ObjectiveC runtime associations
  - **Constants.swift** - App constants and identifiers
- **Permission/PermissionsManager.swift** - Handles file system permissions with bookmark data
- **Settings/** - Settings window and panes
- **Store/** - In-app purchase (StoreKit) management

## Key Architecture Patterns

### State Management
- `AppState` (`@MainActor`) - Global app state passed via `.environmentObject()`
- `iMonetImageView` owns zoom/pan state directly (`magnification`, `offset`), no separate ViewState model

### Naming Conventions
- **Important**: `ToolBarView` (not `ToolbarView`) - file and struct name use two-word "ToolBar"
- Enum identifiers use camelCase: `ToolbarActionIdentifier`

### Concurrency Safety
- Static properties in non-Sendable types require `nonisolated(unsafe)` annotation:
  ```swift
  enum Context {
      nonisolated(unsafe) static let hasActivated = ObjectAssociation<Bool>()
  }
  ```

### Resource Handling
- `Info.plist` and `iMonet.entitlements` are NOT declared in Package.swift (SPM limitation)
- They are handled by Xcode project configuration if using Xcode

### Dependencies
The project has no external dependencies.

### Logging
Use `@AppLog(category: "Name")` property wrapper:
```swift
@AppLog(category: "ViewState")
private var logger
// Usage: logger.info("message"), logger.warning("message"), logger.error("message")
```

### Image Loading Pipeline
1. User selects folder → permissions granted via bookmark data
2. `AppDelegate.loadImages()` scans directory for supported formats (png, jpg, jpeg, gif, webp)
3. Files stored in `AppState.imageFiles: [URL]`
4. `AppState.selectedImageIndex` tracks current image
5. `ImagePreviewView.refreshImage()` loads `NSImage(contentsOf:)` for static display
6. For animated formats (GIF/APNG/WebP), `ImageAnimator` decodes frames via `CGImageSource` and drives playback

### Animated Image Support
- `ImageAnimator` handles GIF, APNG, and animated WebP — format detected via `CGImageSourceGetType`
- Frame delays parsed per-format: GIF uses per-frame properties; APNG/WebP use top-level frame info arrays
- Animation driven by a ~60fps `Timer` with `CACurrentMediaTime()` for accurate delta tracking
- `iMonetImageView.draw(_:)` renders animated `CGImage` frames directly, applying zoom/pan/rotation transforms identically to static images
- Single-frame images skip the animation timer entirely
- Thumbnails always show static first frame

### View Hierarchy (ContentView)
```
ContentView (GeometryReader)
├── ThumbnailSidebar (left, floating, zIndex: 20)
├── ImageInfoPanel (right, floating, zIndex: 20)
├── ImagePreviewView (full area, zIndex: 10)
│   └── ZoomableImageView → iMonetImageRepresentable → iMonetImageView (custom NSView)
├── Navigation arrows (left/right edges, zIndex: 20)
├── ToolBarView (bottom center, floating, zIndex: 20)
└── PurchasePromptView (overlay, zIndex: 100)
```
