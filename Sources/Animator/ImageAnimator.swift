//
//  ImageAnimator.swift
//  iMonet
//
//  Decodes animated image frames (GIF / APNG / WebP) using CGImageSource
//  and drives frame advancement with a high-frequency Timer.
//  Zero external dependencies.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - APNG / WebP property keys (not exported by the macOS Swift overlay)

// CFString is not Sendable; these are read-only string constants safe for concurrent access.
private nonisolated(unsafe) let kAPNGDictionary         = "{APNG}" as CFString
private nonisolated(unsafe) let kAPNGLoopCount          = "LoopCount" as CFString
private nonisolated(unsafe) let kAPNGDelayTime          = "DelayTime" as CFString
private nonisolated(unsafe) let kAPNGUnclampedDelayTime = "UnclampedDelayTime" as CFString
private nonisolated(unsafe) let kAPNGFrameInfoArray     = "FrameInfoArray" as CFString
private nonisolated(unsafe) let kAPNGCanvasPixelWidth   = "CanvasPixelWidth" as CFString
private nonisolated(unsafe) let kAPNGCanvasPixelHeight  = "CanvasPixelHeight" as CFString

private nonisolated(unsafe) let kWebPDictionary         = "{WebP}" as CFString
private nonisolated(unsafe) let kWebPLoopCount          = "LoopCount" as CFString
private nonisolated(unsafe) let kWebPDelayTime          = "DelayTime" as CFString
private nonisolated(unsafe) let kWebPUnclampedDelayTime = "UnclampedDelayTime" as CFString
private nonisolated(unsafe) let kWebPFrameInfoArray     = "FrameInfoArray" as CFString
private nonisolated(unsafe) let kWebPCanvasPixelWidth   = "CanvasPixelWidth" as CFString
private nonisolated(unsafe) let kWebPCanvasPixelHeight  = "CanvasPixelHeight" as CFString

// MARK: - ImageAnimator

final class ImageAnimator: @unchecked Sendable {

    /// Called on the main thread whenever a new frame is ready.
    var onFrameChanged: (() -> Void)?

    /// The current frame as a CGImage, or nil before the first frame loads.
    private(set) var currentFrame: CGImage?

    /// Whether the animation timer is currently scheduled.
    private(set) var isAnimating = false

    /// Total number of frames in the image.
    let frameCount: Int

    /// Logical canvas size (first-frame pixel dimensions).
    let canvasSize: CGSize

    /// 0 = loop forever; n = stop after n complete loops.
    private let loopCount: Int

    /// Per-frame display duration in seconds.
    private let frameDelays: [TimeInterval]

    /// The CGImageSource backed by the image file.
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

    // MARK: - Supported format UTIs

    private enum Format {
        case gif
        case apng
        case webp
    }

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

        // Detect image format
        guard let type = CGImageSourceGetType(source) else { return nil }
        let format: Format
        if type == UTType.gif.identifier as CFString {
            format = .gif
        } else if type == UTType.png.identifier as CFString {
            format = .apng
        } else if type == UTType.webP.identifier as CFString
                  || type == "org.webmproject.webp" as CFString {
            format = .webp
        } else {
            return nil
        }

        // Parse format-specific properties
        let parsed = Self.parseProperties(source: source, count: count, format: format)
        self.frameDelays = parsed.delays
        self.canvasSize = parsed.canvasSize
        self.loopCount = parsed.loopCount

        // Load the very first frame immediately.
        currentFrame = CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    deinit {
        stopAnimation()
    }

    // MARK: - Property parsing

    private struct ParsedProperties {
        var delays: [TimeInterval]
        var canvasSize: CGSize
        var loopCount: Int
    }

    private static func parseProperties(
        source: CGImageSource,
        count: Int,
        format: Format
    ) -> ParsedProperties {
        switch format {
        case .gif:  return parseGIF(source: source, count: count)
        case .apng: return parseAPNG(source: source, count: count)
        case .webp: return parseWebP(source: source, count: count)
        }
    }

    /// GIF: per-frame properties contain the delay and loop count.
    private static func parseGIF(source: CGImageSource, count: Int) -> ParsedProperties {
        var delays: [TimeInterval] = []
        var size = CGSize.zero
        var loops = 0

        for i in 0 ..< count {
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
                  let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
                delays.append(0.1)
                continue
            }

            if i == 0 {
                let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
                let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
                size = CGSize(width: w, height: h)
                if let lc = gifProps[kCGImagePropertyGIFLoopCount] as? Int {
                    loops = lc
                }
            }

            let raw = (gifProps[kCGImagePropertyGIFDelayTime] as? TimeInterval) ?? 0.1
            delays.append(raw > 0 ? raw : 0.05)
        }

        return ParsedProperties(delays: delays, canvasSize: size, loopCount: loops)
    }

    /// APNG: delays come from a top-level frame-info array.
    private static func parseAPNG(source: CGImageSource, count: Int) -> ParsedProperties {
        var delays: [TimeInterval] = []
        var size = CGSize.zero
        var loops = 0

        // Top-level properties
        if let top = CGImageSourceCopyProperties(source, nil) as? [CFString: Any],
           let apng = top[kAPNGDictionary] as? [CFString: Any] {

            if let lc = apng[kAPNGLoopCount] as? Int {
                loops = lc
            }

            // Canvas size (prefer APNG-specific keys)
            let w = (apng[kAPNGCanvasPixelWidth] as? CGFloat)
                 ?? (top[kCGImagePropertyPixelWidth] as? CGFloat)
                 ?? 0
            let h = (apng[kAPNGCanvasPixelHeight] as? CGFloat)
                 ?? (top[kCGImagePropertyPixelHeight] as? CGFloat)
                 ?? 0
            size = CGSize(width: w, height: h)

            // Frame info array
            if let frameInfo = apng[kAPNGFrameInfoArray] as? [[CFString: Any]] {
                for frameDict in frameInfo {
                    let raw = (frameDict[kAPNGUnclampedDelayTime] as? TimeInterval)
                           ?? (frameDict[kAPNGDelayTime] as? TimeInterval)
                           ?? 0.1
                    delays.append(raw > 0 ? raw : 0.05)
                }
            }
        }

        // Fallback: if the array is shorter than frameCount, pad with defaults
        while delays.count < count {
            delays.append(0.1)
        }

        return ParsedProperties(delays: delays, canvasSize: size, loopCount: loops)
    }

    /// WebP: same shape as APNG — frame-info array in top-level properties.
    private static func parseWebP(source: CGImageSource, count: Int) -> ParsedProperties {
        var delays: [TimeInterval] = []
        var size = CGSize.zero
        var loops = 0

        if let top = CGImageSourceCopyProperties(source, nil) as? [CFString: Any],
           let webp = top[kWebPDictionary] as? [CFString: Any] {

            if let lc = webp[kWebPLoopCount] as? Int {
                loops = lc
            }

            let w = (webp[kWebPCanvasPixelWidth] as? CGFloat)
                 ?? (top[kCGImagePropertyPixelWidth] as? CGFloat)
                 ?? 0
            let h = (webp[kWebPCanvasPixelHeight] as? CGFloat)
                 ?? (top[kCGImagePropertyPixelHeight] as? CGFloat)
                 ?? 0
            size = CGSize(width: w, height: h)

            if let frameInfo = webp[kWebPFrameInfoArray] as? [[CFString: Any]] {
                for frameDict in frameInfo {
                    let raw = (frameDict[kWebPUnclampedDelayTime] as? TimeInterval)
                           ?? (frameDict[kWebPDelayTime] as? TimeInterval)
                           ?? 0.1
                    delays.append(raw > 0 ? raw : 0.05)
                }
            }
        }

        while delays.count < count {
            delays.append(0.1)
        }

        return ParsedProperties(delays: delays, canvasSize: size, loopCount: loops)
    }

    // MARK: - Animation lifecycle

    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // Single-frame — just load once, no timer needed.
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
