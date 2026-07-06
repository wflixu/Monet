//
//  GIFAnimator.swift
//  iMonet
//
//  Decodes animated GIF frames using CGImageSource and drives frame
//  advancement with a high-frequency Timer.  Zero external dependencies.
//

import AppKit
import ImageIO

final class GIFAnimator: @unchecked Sendable {

    /// Called on the main thread whenever a new frame is ready.
    var onFrameChanged: (() -> Void)?

    /// The current frame as a CGImage, or nil before the first frame loads.
    private(set) var currentFrame: CGImage?

    /// Whether the animation timer is currently scheduled.
    private(set) var isAnimating = false

    /// Total number of frames in the GIF.
    let frameCount: Int

    /// Logical canvas size (first-frame pixel dimensions).
    let canvasSize: CGSize

    /// 0 = loop forever; n = stop after n complete loops.
    private let loopCount: Int

    /// Per-frame display duration in seconds.
    private let frameDelays: [TimeInterval]

    /// The CGImageSource backed by the GIF file.
    private let imageSource: CGImageSource

    /// Current frame index (0 ..< frameCount).
    private var currentFrameIndex = 0

    /// Number of completed loops.
    private var currentLoop = 0

    /// Accumulated time since the last frame advance.
    private var elapsed: TimeInterval = 0

    /// High-frequency timer driving frame updates (~60 fps).
    private var timer: Timer?

    /// Timestamp of the previous timer fire, used for delta-time calculation.
    private var lastFireTime: CFTimeInterval = 0

    // MARK: - Init

    /// Failable initialiser.  Returns nil if the URL cannot be opened as an
    /// image source or contains zero frames.
    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        self.imageSource = source

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        self.frameCount = count

        // ---- parse per-frame delays & determine canvas size / loop count ----
        var delays: [TimeInterval] = []
        var size = CGSize.zero
        var loops = 0

        for i in 0 ..< count {
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] else {
                delays.append(0.1)
                continue
            }

            // Canvas size from the first frame
            if i == 0 {
                if let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
                   let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
                    size = CGSize(width: w, height: h)
                }
            }

            // GIF-specific dictionary
            guard let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
                delays.append(0.1)
                continue
            }

            // Per-frame delay (seconds).  Clamp 0 → 0.05 to avoid burning CPU.
            let raw = (gifProps[kCGImagePropertyGIFDelayTime] as? TimeInterval) ?? 0.1
            delays.append(raw > 0 ? raw : 0.05)

            // Loop count is stored on the first frame only
            if i == 0 {
                if let lc = gifProps[kCGImagePropertyGIFLoopCount] as? Int {
                    loops = lc  // 0 = forever
                }
            }
        }

        self.frameDelays = delays
        self.canvasSize = size
        self.loopCount = loops

        // Load the very first frame immediately so something is visible even
        // before the timer fires.
        currentFrame = CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    deinit {
        stopAnimation()
    }

    // MARK: - Animation lifecycle

    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // Single-frame GIF — just load once, no timer needed.
        if frameCount <= 1 { return }

        lastFireTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.timerStep()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopAnimation() {
        timer?.invalidate()
        timer = nil
        isAnimating = false
        currentFrame = nil
    }

    // MARK: - Frame stepping

    private func timerStep() {
        autoreleasepool {
            let now = CACurrentMediaTime()
            let delta = now - lastFireTime
            lastFireTime = now
            guard delta > 0 else { return }

            elapsed += delta
            let targetDelay = frameDelays[currentFrameIndex]

            guard elapsed >= targetDelay else { return }
            elapsed -= targetDelay

            // Advance
            currentFrameIndex += 1
            if currentFrameIndex >= frameCount {
                currentLoop += 1
                if loopCount > 0 && currentLoop >= loopCount {
                    // Finished all loops — stay on the last frame and stop.
                    timer?.invalidate()
                    timer = nil
                    // Reload the last frame for display.
                    currentFrame = CGImageSourceCreateImageAtIndex(imageSource, frameCount - 1, nil)
                    isAnimating = false
                    onFrameChanged?()
                    return
                }
                currentFrameIndex = 0
            }

            let newFrame = CGImageSourceCreateImageAtIndex(imageSource, currentFrameIndex, nil)
            if let newFrame {
                currentFrame = newFrame
                onFrameChanged?()
            }
        }
    }
}
