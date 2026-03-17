# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Monet is a macOS image viewer application built with SwiftUI, focused on efficient image viewing and navigation with keyboard shortcuts and mouse interactions.

## Build and Run

```bash
swift run                    # Build and run the app
swift test                   # Run tests
```

## Project Structure

The codebase follows a modular SwiftUI architecture:

- **MonetApp.swift** - App entry point with `@main`, defines scenes (main window, settings, menu bar extra)
- **AppState.swift** - Global application state (`@MainActor class`), manages image URLs, permissions, settings
- **AppDelegate** - Handles file opening requests, window styling, and app lifecycle
- **Views/**:
  - **ContentView.swift** - Legacy main view with sidebar thumbnail navigation
  - **LayoutView.swift** - New layout view with floating UI components
  - **ZoomableImageView.swift** - Image view with pan/zoom support
  - **ToolBarView.swift** - Bottom toolbar with navigation controls (note spelling: `ToolBarView`, not `ToolbarView`)
  - **InfoBarView.swift** - Top info bar
  - **NavigationFloatView.swift** - Left navigation panel
- **Models/ViewState.swift** - Image transformation state (scale, offset, anchor, rotation)
- **Shared/**:
  - **AppLogger.swift** - `@AppLog` property wrapper for logging
  - **Util.swift** - `ObjectAssociation` for ObjectiveC runtime associations
  - **Constants.swift** - App constants and identifiers
- **Permission/PermissionsManager.swift** - Handles file system permissions with bookmark data

## Key Architecture Patterns

### State Management
- `AppState` (`@MainActor`) - Global app state passed via `.environmentObject()`
- `ViewState` - Per-view image transformation state, used by `ZoomableImageView`

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
- `Info.plist` and `Monet.entitlements` are NOT declared in Package.swift (SPM limitation)
- They are handled by Xcode project configuration if using Xcode

### Dependencies
- **SDWebImageSwiftUI** - Image loading (`import SDWebImageSwiftUI`)
- **LaunchAtLogin-Modern** - Login launch (product: `LaunchAtLogin`)
- **SwiftUITooltip** - Tooltips (product: `SwiftUITooltip` from `SwiftUI-Tooltip` package)

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

### View Hierarchy (LayoutView)
```
LayoutView (GeometryReader)
├── ZoomableImageView (background)
├── InfoBarView (top, floating)
├── NavigationFloatView (left, floating)
└── ToolBarView (bottom, floating)
```
