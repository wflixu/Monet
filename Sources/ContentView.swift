//
//  ContentView.swift
//  iMonet
//

import SwiftUI

struct ContentView: View {
    @AppLog(category: "ContentView")
    private var logger

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager

    @State private var scale: CGSize = .init(width: 1, height: 1)
    @State private var isNavBarVisible = true
    @State private var window: NSWindow?
    @State private var monetImageView: iMonetImageView?
    @State private var isChromeVisible = true
    @State private var chromeTimer: Timer?
    @State private var isInfoPanelVisible = false
    @State private var showPurchasePrompt = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if isNavBarVisible && appState.imageFiles.count > 1 {
                    ThumbnailSidebar(
                        imageFiles: appState.imageFiles,
                        selectedIndex: appState.selectedImageIndex,
                        windowHeight: window?.frame.size.height ?? 720,
                        onSelect: { index in
                            appState.selectedImageIndex = index
                            appState.currentImageURL = appState.imageFiles[index]
                            NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
                        }
                    )
                    .zIndex(20)
                }

                if isInfoPanelVisible {
                    ImageInfoPanel(
                        imageURL: appState.currentImageURL,
                        windowHeight: window?.frame.size.height ?? 720,
                        onClose: { isInfoPanelVisible = false }
                    )
                    .zIndex(20)
                    .position(x: geometry.size.width - 130, y: (window?.frame.size.height ?? 720) / 2)
                }

                ImagePreviewView(scale: $scale, monetImageView: $monetImageView, onClick: toggleChrome, onDelete: confirmDelete, onNavigate: showChrome)
                    .frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)

                // Left navigation arrow
                if appState.selectedImageIndex > 0 {
                    navArrowButton(
                        systemName: "chevron.left",
                        action: { navigateToPrevious() }
                    )
                    .opacity(isChromeVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isChromeVisible)
                    .zIndex(20)
                    .position(x: (isNavBarVisible && appState.imageFiles.count > 1) ? 160 : 32,
                              y: geometry.size.height / 2)
                }

                // Right navigation arrow
                if appState.selectedImageIndex < appState.imageFiles.count - 1 {
                    navArrowButton(
                        systemName: "chevron.right",
                        action: { navigateToNext() }
                    )
                    .opacity(isChromeVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isChromeVisible)
                    .zIndex(20)
                    .position(x: geometry.size.width - 32, y: geometry.size.height / 2)
                }

                ToolBarView(scale: scale, onTap: { actionID in
                    handleToolbarTap(actionID)
                }, onHoverEnter: cancelChromeTimer, onHoverExit: resetChromeTimer)
                .opacity(isChromeVisible ? 1 : 0)
                .allowsHitTesting(isChromeVisible)
                .animation(.easeInOut(duration: 0.3), value: isChromeVisible)
                .zIndex(20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 32)

                if showPurchasePrompt {
                    PurchasePromptView(isPresented: $showPurchasePrompt)
                        .zIndex(100)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea(.container)
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9))
            .onAppear(perform: appearHandler)
            .onReceive(NotificationCenter.default.publisher(for: .showPurchasePrompt)) { _ in
                checkPurchasePrompt()
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    if point.y > geometry.size.height - 48 {
                        showChrome()
                    } else if isChromeVisible {
                        resetChromeTimer()
                    }
                case .ended:
                    if isChromeVisible {
                        resetChromeTimer()
                    }
                }
            }
        }
    }

    // MARK: - Navigation Arrow Button

    func navArrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.ultraThinMaterial).opacity(0.7))
        }
        .buttonStyle(PlainButtonStyle())
        .help(Text(systemName.contains("left") ? "Previous picture" : "Next picture"))
    }

    // MARK: - Toolbar Actions

    func handleToolbarTap(_ id: ToolbarActionIdentifier) {
        switch id {
        case .toggleNav:
            isNavBarVisible.toggle()

        case .scaleMinis:
            monetImageView?.zoomOut()

        case .scalePlus:
            monetImageView?.zoomIn()

        case .showPrev:
            navigateToPrevious()

        case .showNext:
            navigateToNext()

        case .centerFill:
            monetImageView?.fitToWindow()

        case .toggleInfo:
            isInfoPanelVisible.toggle()

        case .rotateLeft:
            rotateCurrentImage(by: -90)

        case .rotateRight:
            rotateCurrentImage(by: 90)

        case .deleteImage:
            confirmDelete()
        }
    }

    // MARK: - Navigation

    func navigateToPrevious() {
        guard appState.selectedImageIndex > 0 else { return }
        appState.selectedImageIndex -= 1
        appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
        NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
    }

    func navigateToNext() {
        guard appState.selectedImageIndex < appState.imageFiles.count - 1 else { return }
        appState.selectedImageIndex += 1
        appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
        NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
    }

    // MARK: - Delete

    func confirmDelete() {
        guard let url = appState.currentImageURL else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Delete Picture")
        let format = String(localized: "Are you sure you want to move \"%@\" to the Trash?")
        alert.informativeText = String(format: format, url.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        guard let window = NSApplication.shared.windows.first else { return }
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                performDelete(url: url)
            }
        }
    }

    func performDelete(url: URL) {
        NSWorkspace.shared.recycle([url]) { recycledURLs, error in
            DispatchQueue.main.async {
                if let error {
                    logger.error("Failed to move to trash: \(error.localizedDescription)")
                    return
                }
                appState.imageFiles.removeAll { $0 == url }
                if appState.imageFiles.isEmpty {
                    appState.currentImageURL = nil
                    appState.selectedImageIndex = 0
                } else if appState.selectedImageIndex >= appState.imageFiles.count {
                    appState.selectedImageIndex = appState.imageFiles.count - 1
                    appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
                    NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
                } else {
                    appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
                    NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
                }
                logger.info("Moved to trash: \(url.lastPathComponent)")
            }
        }
    }

    // MARK: - Rotation

    /// Routes rotation to display-only (GIF) or file-based (static images).
    func rotateCurrentImage(by degrees: CGFloat) {
        guard let url = appState.currentImageURL else { return }
        let isGIF = url.pathExtension.lowercased() == "gif"
        if isGIF {
            // Display-only rotation — preserves animation frames.
            if degrees > 0 {
                monetImageView?.rotateRight()
            } else {
                monetImageView?.rotateLeft()
            }
        } else {
            rotateImage(at: url, by: degrees)
        }
    }

    func rotateImage(at url: URL, by degrees: CGFloat) {
        guard let image = NSImage(contentsOf: url) else { return }

        let isVerticalFlip = Int(abs(degrees)) % 180 == 90
        let newSize = isVerticalFlip
            ? NSSize(width: image.size.height, height: image.size.width)
            : image.size

        let rotated = NSImage(size: newSize, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
            transform.rotate(byDegrees: degrees)
            transform.translateX(by: -image.size.width / 2, yBy: -image.size.height / 2)
            transform.concat()
            image.draw(in: NSRect(origin: .zero, size: image.size))
            return true
        }

        guard let tiff = rotated.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return }

        let ext = url.pathExtension.lowercased()
        let data: Data?
        switch ext {
        case "png":  data = bitmap.representation(using: .png, properties: [:])
        case "jpg", "jpeg": data = bitmap.representation(using: .jpeg, properties: [:])
        case "gif":  data = bitmap.representation(using: .gif, properties: [:])
        case "webp": data = bitmap.representation(using: .png, properties: [:])
        default:     data = bitmap.representation(using: .png, properties: [:])
        }

        guard let data else { return }
        do {
            try data.write(to: url)
            NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
        } catch {
            logger.error("Failed to save rotated image: \(error.localizedDescription)")
        }
    }

    // MARK: - Chrome Visibility

    func appearHandler() {
        if let window = NSApplication.shared.windows.first {
            self.window = window
        }
        showChrome()
        checkPurchasePrompt()
    }

    func checkPurchasePrompt() {
        if UsageTracker.shouldShowPrompt() && !storeManager.isPurchased {
            showPurchasePrompt = true
        }
    }

    func toggleChrome() {
        if isChromeVisible {
            hideChrome()
        } else {
            showChrome()
        }
    }

    func showChrome() {
        isChromeVisible = true
        cancelChromeTimer()
    }

    func hideChrome() {
        isChromeVisible = false
        chromeTimer?.invalidate()
        chromeTimer = nil
    }

    func resetChromeTimer() {
        chromeTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isChromeVisible = false
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        chromeTimer = timer
    }

    func cancelChromeTimer() {
        chromeTimer?.invalidate()
        chromeTimer = nil
    }
}

#Preview {
    ContentView()
}
