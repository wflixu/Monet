[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-ED523F.svg?style=flat)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)](https://developer.apple.com/xcode/swiftui/)
[![macOS 15](https://img.shields.io/badge/macOS15-Compatible-green)](https://www.apple.com/macos/)

<div align="start">
   <img src="Sources/Monet/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="256" height="256" alt="Monet Logo"/>
</div>

# Monet

An elegant image viewer for macOS, powered by SwiftUI.

## Features

### Image Browsing
- **Folder Access**: Request folder access on startup to browse your images
- **Auto-Indexing**: Automatically scans and indexes all supported image formats
- **Supported Formats**: PNG, JPEG, GIF, WebP

### Keyboard Navigation
- **Arrow Keys**: Navigate through images with arrow keys (←/→/↑/↓)
- **Quick Switch**: Browse all images without touching the mouse

### Zoom & Pan
- **Command + Scroll**: Zoom in/out centered on mouse position
- **Mouse Drag**: Pan around zoomed images
- **Zoom Range**: Supports 0.1x to 10x zoom levels

### Floating UI
- **Info Bar** (top): Shows current zoom level and file name
- **Navigation Panel** (left): Thumbnail strip for quick navigation
- **Toolbar** (bottom): Image counter and navigation controls

## Requirements

- macOS 15.0 or later
- Xcode 16.0 or later
- Swift 6.0+

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/Monet.git
cd Monet

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open in Xcode
open Monet.xcodeproj

# Or build from command line
xcodebuild -project Monet.xcodeproj -scheme Monet build
```

## Project Structure

```
Monet/
├── Sources/
│   └── Monet/
│       ├── MonetApp.swift              # App entry point
│       ├── AppState.swift               # Global app state
│       ├── LayoutView.swift             # Main layout view
│       ├── ZoomableImageView.swift      # Zoomable image view
│       ├── Views/
│       │   ├── ToolBarView.swift        # Bottom toolbar
│       │   ├── InfoBarView.swift        # Top info bar
│       │   └── NavigationFloatView.swift # Left navigation panel
│       ├── Models/
│       │   └── ViewState.swift          # Image transformation state
│       ├── Permission/
│       │   └── PermissionsManager.swift # File system permissions
│       ├── Settings/
│       │   ├── GeneralSettingsPane.swift
│       │   └── AboutSettingsPane.swift
│       ├── Shared/
│       │   ├── AppLogger.swift          # Logging utilities
│       │   ├── Constants.swift
│       │   └── Util.swift
│       ├── Assets.xcassets/             # App resources
│       ├── Info.plist                   # App configuration
│       └── Monet.entitlements           # Sandbox entitlements
├── Tests/
│   └── MonetTests/
├── project.yml                          # XcodeGen project spec
└── Monet.xcodeproj/                     # Generated Xcode project
```

## Development

Monet is built with:
- **SwiftUI** for the user interface
- **SDWebImageSwiftUI** for image loading
- **LaunchAtLogin** for login item management
- **SwiftUI-Tooltip** for tooltips

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ← / → | Previous / Next image |
| ↑ / ↓ | Previous / Next image |
| Cmd + Scroll | Zoom in/out |
| Mouse Drag | Pan zoomed image |

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
