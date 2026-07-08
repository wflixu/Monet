import AppKit
import SwiftUI

// MARK: - NSView: Image display with zoom & pan

final class iMonetImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    /// Attach a GIF animator to this view. The animator drives frame updates
    /// and `draw(_:)` renders the current frame instead of `image`.
    var animator: ImageAnimator? {
        didSet {
            oldValue?.stopAnimation()
            oldValue?.onFrameChanged = nil
            guard let animator else { return }
            animator.onFrameChanged = { [weak self] in
                self?.needsDisplay = true
            }
            if window != nil {
                animator.startAnimation()
            }
            needsDisplay = true
        }
    }

    /// Display-only rotation in degrees (0, 90, 180, 270).
    var rotationDegrees: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var onStateChanged: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    var isDarkMode = false

    private(set) var magnification: CGFloat = 1.0
    private var offset: CGPoint = .zero
    private var hasPerformedInitialFit = false

    private let minMag: CGFloat = 0.1
    private let maxMag: CGFloat = 16.0

    // Pan state
    private var dragStartPoint: CGPoint = .zero
    private var dragStartOffset: CGPoint = .zero
    private var isPotentialClick = false

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            if !hasPerformedInitialFit {
                DispatchQueue.main.async { [weak self] in
                    self?.fitToWindow()
                }
            }
            animator?.startAnimation()
        } else {
            animator?.stopAnimation()
        }
    }

    override func layout() {
        super.layout()
        if !hasPerformedInitialFit, bounds.width > 0, bounds.height > 0 {
            fitToWindow()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let fillColor: NSColor = isDarkMode
            ? NSColor(white: 0.15, alpha: 1.0)
            : NSColor(white: 0.9, alpha: 1.0)
        fillColor.setFill()
        bounds.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Determine the image to draw and its pixel dimensions.
        let cgImage: CGImage?
        let drawWidth: CGFloat
        let drawHeight: CGFloat

        if let animFrame = animator?.currentFrame {
            cgImage = animFrame
            drawWidth = CGFloat(animFrame.width)
            drawHeight = CGFloat(animFrame.height)
        } else if let image {
            cgImage = nil
            drawWidth = image.size.width
            drawHeight = image.size.height
        } else {
            return
        }

        context.saveGState()

        // Transform: center in view → apply pan offset → scale → rotate
        let cx = bounds.width / 2 + offset.x
        let cy = bounds.height / 2 + offset.y
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: magnification, y: magnification)
        if rotationDegrees != 0 {
            context.rotate(by: rotationDegrees * .pi / 180)
        }

        let imageRect = CGRect(
            x: -drawWidth / 2,
            y: -drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )

        if let cgImage {
            context.draw(cgImage, in: imageRect)
        } else if let image {
            let nsRect = NSRect(
                x: -drawWidth / 2,
                y: -drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )
            image.draw(in: nsRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        context.restoreGState()
    }

    // MARK: - Scroll Wheel (Command + scroll = zoom)

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.scrollWheel(with: event)
            return
        }

        let factor: CGFloat = event.scrollingDeltaY > 0 ? 1.1 : 0.9
        let newMag = (magnification * factor).clamped(to: minMag...maxMag)
        guard newMag != magnification else { return }

        let scaleRatio = newMag / magnification

        // Mouse position in this view's coordinate system (bottom-left origin)
        let mouseInView = convert(event.locationInWindow, from: nil)

        // Convert to center-relative coordinates
        let mouseCenteredX = mouseInView.x - bounds.width / 2
        let mouseCenteredY = mouseInView.y - bounds.height / 2

        // Compute new offset such that the pixel under the mouse stays fixed
        let newOffsetX = (offset.x - mouseCenteredX) * scaleRatio + mouseCenteredX
        let newOffsetY = (offset.y - mouseCenteredY) * scaleRatio + mouseCenteredY

        magnification = newMag
        offset = CGPoint(x: newOffsetX, y: newOffsetY)

        needsDisplay = true
        onStateChanged?(magnification)
    }

    // MARK: - Magnify Gesture (trackpad pinch-to-zoom)

    override func magnify(with event: NSEvent) {
        // magnification is the delta since the last event, apply directly
        let factor = 1 + event.magnification
        let newMag = (magnification * factor).clamped(to: minMag...maxMag)
        guard newMag != magnification else { return }

        let scaleRatio = newMag / magnification

        let mouseInView = convert(event.locationInWindow, from: nil)
        let mouseCenteredX = mouseInView.x - bounds.width / 2
        let mouseCenteredY = mouseInView.y - bounds.height / 2

        let newOffsetX = (offset.x - mouseCenteredX) * scaleRatio + mouseCenteredX
        let newOffsetY = (offset.y - mouseCenteredY) * scaleRatio + mouseCenteredY

        magnification = newMag
        offset = CGPoint(x: newOffsetX, y: newOffsetY)
        needsDisplay = true
        onStateChanged?(magnification)
    }

    // MARK: - Mouse Drag (pan)

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartOffset = offset
        isPotentialClick = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        if abs(dx) > 3 || abs(dy) > 3 {
            isPotentialClick = false
        }

        let newOffsetX = dragStartOffset.x + dx
        let newOffsetY = dragStartOffset.y + dy

        guard newOffsetX.isFinite, newOffsetY.isFinite else { return }

        offset = CGPoint(x: newOffsetX, y: newOffsetY)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPotentialClick {
            onClick?()
        }
        isPotentialClick = false
    }

    // MARK: - Fit to Window

    func fitToWindow() {
        // Determine the logical draw size, accounting for rotation.
        let drawSize = effectiveDrawSize()
        guard drawSize.width > 0, drawSize.height > 0 else { return }
        guard bounds.width > 0, bounds.height > 0 else { return }

        let fitMag = min(
            bounds.width / drawSize.width,
            bounds.height / drawSize.height
        )
        magnification = fitMag
        offset = .zero
        hasPerformedInitialFit = true
        needsDisplay = true

        onStateChanged?(magnification)
    }

    /// The size of the thing we are drawing, swapping width/height when
    /// rotation is close to 90° or 270°.
    private func effectiveDrawSize() -> CGSize {
        let raw: CGSize
        if let canvasSize = animator?.canvasSize, canvasSize != .zero {
            raw = canvasSize
        } else if let image {
            raw = image.size
        } else {
            return .zero
        }
        let deg = abs(rotationDegrees).truncatingRemainder(dividingBy: 360)
        if (deg > 45 && deg < 135) || (deg > 225 && deg < 315) {
            return CGSize(width: raw.height, height: raw.width)
        }
        return raw
    }

    // MARK: - Display-only Rotation

    func rotateLeft() {
        rotationDegrees -= 90
        // Rotation changes the effective draw size → re-fit.
        fitToWindow()
    }

    func rotateRight() {
        rotationDegrees += 90
        fitToWindow()
    }

    // MARK: - Toolbar Zoom Actions

    /// Required by AppKit's print infrastructure.
    /// `NSPrintOperation.run()` verifies that the responder chain contains a
    /// responder to `printDocument:` before presenting the print panel.
    /// Since `iMonetImageView` is an `NSView` (part of the responder chain),
    /// placing the action here satisfies that check.
    @objc func printDocument(_ sender: Any?) { }

    func zoomIn() {
        zoomAtCenter(factor: 1.25)
    }

    func zoomOut() {
        zoomAtCenter(factor: 0.8)
    }

    func actualSize() {
        magnification = 1.0
        offset = .zero
        needsDisplay = true
        onStateChanged?(magnification)
    }

    private func zoomAtCenter(factor: CGFloat) {
        let newMag = (magnification * factor).clamped(to: minMag...maxMag)
        guard newMag != magnification else { return }

        let scaleRatio = newMag / magnification
        magnification = newMag
        offset.x = offset.x * scaleRatio
        offset.y = offset.y * scaleRatio
        needsDisplay = true
        onStateChanged?(magnification)
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - NSViewRepresentable bridge

struct iMonetImageRepresentable: NSViewRepresentable {
    let image: NSImage?
    let animator: ImageAnimator?
    let isDarkMode: Bool
    var onStateChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((iMonetImageView) -> Void)?
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> iMonetImageView {
        let view = iMonetImageView()
        view.image = image
        view.animator = animator
        view.isDarkMode = isDarkMode
        view.onStateChanged = onStateChanged
        view.onClick = onClick
        DispatchQueue.main.async {
            onViewCreated?(view)
        }
        return view
    }

    func updateNSView(_ nsView: iMonetImageView, context: Context) {
        nsView.image = image
        nsView.animator = animator
        nsView.isDarkMode = isDarkMode
        nsView.onStateChanged = onStateChanged
        nsView.onClick = onClick
    }
}

// MARK: - SwiftUI Wrapper

struct ZoomableImageView: View {
    @Environment(\.colorScheme) private var colorScheme

    let image: NSImage?
    var animator: ImageAnimator?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((iMonetImageView) -> Void)?
    var onClick: (() -> Void)?

    var body: some View {
        iMonetImageRepresentable(
            image: image,
            animator: animator,
            isDarkMode: colorScheme == .dark,
            onStateChanged: onScaleChanged,
            onViewCreated: onViewCreated,
            onClick: onClick
        )
    }
}

#Preview {
    ZoomableImageView(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil))
        .background(Color.gray)
}
