//
//  ImagePreviewView.swift
//  iMonet
//

import AppKit
import SwiftUI

struct ImagePreviewView: View {
    @AppLog(category: "ImagePreview")
    private var logger

    @EnvironmentObject var appState: AppState

    @Binding var scale: CGSize
    @Binding var monetImageView: iMonetImageView?

    var onClick: (() -> Void)?
    var onDelete: (() -> Void)?
    var onNavigate: (() -> Void)?

    @State private var currentImage: NSImage?
    @State private var currentAnimator: GIFAnimator?
    @State private var showFileImporter = false

    var body: some View {
        Group {
            if let currentImage = currentImage {
                ZoomableImageView(image: currentImage,
                    animator: currentAnimator,
                    onScaleChanged: { newScale in
                        scale = CGSize(width: newScale, height: newScale)
                    },
                    onViewCreated: { imageView in
                        monetImageView = imageView
                    },
                    onClick: onClick
                )
                .contextMenu {
                    Button("Copy Image Path") {
                        let path = appState.currentImageURL?.path ?? ""
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                    Button("Copy Image") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([currentImage])
                    }
                }
            } else {
                Button("Select Image File") {
                    showFileImporter = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.png, .jpeg, .gif, .webP]
        ) { result in
            if case .success(let url) = result {
                let gotAccess = url.startAccessingSecurityScopedResource()
                if !gotAccess {
                    logger.warning("Failed to access security-scoped resource")
                    return
                }
                if let delegate = appState.appDelegate {
                    delegate.loadImages(from: url)
                    refreshImage()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("open-image"))) { _ in
            refreshImage()
        }
        .onAppear {
            setupKeyEvents()
            refreshImage()
        }
    }

    func setupKeyEvents() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 124, 125: // Right / Down Arrow
                Task { @MainActor in
                    showNextImage()
                    onNavigate?()
                }
                return nil
            case 123, 126: // Left / Up Arrow
                Task { @MainActor in
                    showPreviousImage()
                    onNavigate?()
                }
                return nil
            case 51, 117: // Backspace / Forward Delete
                Task { @MainActor in
                    onDelete?()
                }
                return nil
            default:
                return event
            }
        }
    }

    func refreshImage() {
        guard appState.imageFiles.indices.contains(appState.selectedImageIndex) else {
            return
        }
        let url = appState.imageFiles[appState.selectedImageIndex]

        // Stop any running animation from the previous image.
        currentAnimator?.stopAnimation()
        currentAnimator = nil

        // Load the static NSImage (always — used as fallback and for non-GIF images).
        currentImage = NSImage(contentsOf: url)

        // For GIF files attempt to create an animator (skipped for single-frame GIFs).
        if url.pathExtension.lowercased() == "gif",
           let animator = GIFAnimator(url: url),
           animator.frameCount > 1 {
            currentAnimator = animator
        }
    }

    private func showNextImage() {
        if appState.selectedImageIndex < appState.imageFiles.count - 1 {
            appState.selectedImageIndex += 1
            appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
            refreshImage()
        }
    }

    private func showPreviousImage() {
        if appState.selectedImageIndex > 0 {
            appState.selectedImageIndex -= 1
            appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
            refreshImage()
        }
    }
}
