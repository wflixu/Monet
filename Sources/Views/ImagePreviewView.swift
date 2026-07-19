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
    @State private var currentAnimator: ImageAnimator?
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
                    Button("Print") {
                        printImage(currentImage)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("print-image"))) { _ in
            if let image = currentImage {
                printImage(image)
            }
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

        // Reset display-only view state (rotation, zoom, pan) for the new image
        monetImageView?.rotationDegrees = 0
        monetImageView?.fitToWindow()

        // Load the static NSImage (always — used as fallback and for non-GIF images).
        currentImage = NSImage(contentsOf: url)

        // For animated formats attempt to create an animator.
        let animatedExtensions = ["gif", "png", "webp"]
        if animatedExtensions.contains(url.pathExtension.lowercased()),
           let animator = ImageAnimator(url: url),
           animator.frameCount > 1 {
            currentAnimator = animator
        }
    }

    private func printImage(_ image: NSImage) {
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown

        let printOperation = NSPrintOperation(view: imageView)
        if printOperation.run() {
            logger.info("Print job submitted for image (\(image.size.width)x\(image.size.height))")
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
