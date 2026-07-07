[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-ED523F.svg?style=flat)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)](https://developer.apple.com/xcode/swiftui/)
[![macOS 15](https://img.shields.io/badge/macOS15-Compatible-green)](https://www.apple.com/macos/)

<div align="center">
   <img src="assets/iMonet-logo.png" width="128" height="128" alt="iMonet Logo"/>
</div>

# iMonet

A modern image viewer for macOS with native animated GIF, APNG, and WebP playback. Built with SwiftUI — zero external dependencies.

[![Download on the App Store](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://apps.apple.com/cn/app/imonet/id6770070921?mt=12)

## Demo

https://github.com/user-attachments/assets/f9faccb3-531e-4000-bc7f-e58fb922e6da

## Screenshots

<div align="center">
   <img src="assets/imonet-screenshot.png" width="720" alt="iMonet Screenshot"/>
   <br/><br/>
   <table>
     <tr>
       <td><img src="assets/iMonet-viewer.png" width="360" alt="iMonet Viewer"/></td>
       <td><img src="assets/iMonet-setting.png" width="360" alt="iMonet Settings"/></td>
     </tr>
   </table>
   <img src="assets/iMonet-app-store.png" width="720" alt="iMonet App Store"/>
</div>

## Features

### Image Browsing
- **Folder Indexing**: Automatically scans and indexes all images in the same folder
- **Persistent Permissions**: Uses security-scoped bookmarks so you only grant folder access once
- **Supported Formats**: PNG, JPEG, GIF (animated), APNG (animated), WebP (animated)
- **Animation Playback**: Frame-accurate playback with loop support, zoom/pan during animation
- **Sidebar**: Thumbnail strip for quick navigation, auto-hides with single image

### Mouse & Keyboard
- **Arrow Keys**: ←/→/↑/↓ to navigate images
- **Cmd + Scroll**: Zoom in/out centered at mouse position
- **Mouse Drag**: Pan around zoomed images
- **Click to Reveal**: Click image area to show controls, auto-hide after 5s

### Floating UI
- **Title & Toolbar**: Appear on click, auto-hide after 5 seconds; hover toolbar to keep visible
- **Image Info Panel** (right): Pixel size, file size, format, modification date
- **Dark / Light Mode**: Full adaptive theme support
- **Menu Bar Extra**: Quick access from the menu bar

## Requirements

- macOS 15.0 or later
- Swift 6.0+

## Build & Run

```bash
git clone https://github.com/wflixu/iMonet.git
cd iMonet
swift run
```

For a Release `.app` bundle:

```bash
xcodebuild -scheme iMonet -configuration Release -derivedDataPath build -destination "platform=macOS,arch=arm64" ARCHS=arm64 ENABLE_HARDENED_RUNTIME=YES build
```

## Project Structure

```
iMonet/
├── Sources/iMonet/
│   ├── iMonetApp.swift              # App entry point, scenes, AppDelegate
│   ├── AppState.swift              # Global app state
│   ├── ContentView.swift           # Main layout, chrome auto-hide logic
│   ├── NavigationIdentifier.swift  # Settings navigation
│   ├── Animator/
│   │   └── ImageAnimator.swift     # Animated GIF/APNG/WebP decoder
│   ├── Views/
│   │   ├── ImagePreviewView.swift  # Image display with keyboard events
│   │   ├── ImageThumbnailView.swift
│   │   ├── ThumbnailSidebar.swift  # Left thumbnail strip
│   │   ├── ImageInfoPanel.swift    # Right info panel (pixels, size, format)
│   │   ├── ToolbarView.swift       # Bottom floating toolbar
│   │   └── ZoomableImageView.swift # Zoom & pan image view (AppKit)
│   ├── Settings/
│   │   ├── GeneralSettingsPane.swift
│   │   ├── AboutSettingsPane.swift
│   │   ├── SettingsView.swift
│   │   └── SettingsWindow.swift
│   ├── Permission/
│   │   └── PermissionsManager.swift
│   └── Shared/
│       ├── AppLogger.swift         # @AppLog property wrapper
│       ├── Constants.swift
│       └── Util.swift              # ObjectAssociation
├── Tests/
└── Package.swift
```

## Dependencies

None — iMonet uses only Apple frameworks (SwiftUI, AppKit, ImageIO). Zero external dependencies.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ← / → | Previous / Next image |
| ↑ / ↓ | Previous / Next image |
| Cmd + Scroll | Zoom in/out at mouse position |
| Mouse Drag | Pan zoomed image |

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
