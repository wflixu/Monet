//
//  ViewState.swift
//  Monet
//
//  Created by luke on 2025/11/8.
//

import Combine
import SwiftUI

class ViewState: ObservableObject {
    @Published var scale: Double = 1.0
    @Published var offset: CGSize = .zero
    @Published var anchor: UnitPoint = .center
    @Published var rotation: Double = 0.0
    @Published var fitToWindow: Bool = true

    // Click position tracking
    @Published var clickPosition: CGPoint?
    @Published var imageSize: CGSize = .zero

    // Constants
    private let minScale: Double = 0.1
    private let maxScale: Double = 10.0

    init() {}

    // MARK: - Click Position Tracking

    func recordClickPosition(_ position: CGPoint) {
        clickPosition = position
        updateAnchorBasedOnClick()
    }

    // MARK: 根据imageSize 和 clickPosition 计算 anchor

    func updateAnchorBasedOnClick() {
        guard let clickPos = clickPosition, imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        // 考虑 offset 的影响，计算实际在图像上的位置
        let imageX = (clickPos.x - offset.width / scale) 
        let imageY = (clickPos.y - offset.height / scale)

        // 归一化到图像尺寸
        let normalizedX = clickPos.x / imageSize.width
        let normalizedY = clickPos.y / imageSize.height

        // 确保 anchor 值在 0-1 范围内
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))

        let newOffset = CGSize(
            width: offset.width + (anchor.x - clampedX) * imageSize.width * scale,
            height: offset.height + (anchor.y - clampedY) * imageSize.height * scale
        )
        anchor = UnitPoint(x: clampedX, y: clampedY)
        offset = newOffset
    }

    func clearClickPosition() {
        clickPosition = nil
    }

    // MARK: - Zoom Operations

    func zoom(factor: Double) {
        let newScale = scale * factor

        if newScale != scale {
            scale = newScale
        }
    }

    func pan(delta: CGSize) {
        // 确保增量是有效值
        guard delta.width.isFinite && delta.height.isFinite else {
            return
        }

        let newOffset = CGSize(
            width: offset.width + delta.width,
            height: offset.height + delta.height
        )

        // 确保新的偏移量也是有效值
        guard newOffset.width.isFinite && newOffset.height.isFinite else {
            return
        }

        offset = newOffset
    }

    func setPan(offset: CGSize) {
        // 确保偏移量是有效值
        guard offset.width.isFinite && offset.height.isFinite else {
            return
        }
        self.offset = offset
    }

    func reset() {
        scale = 1.0
        offset = .zero
        anchor = .center
        rotation = 0.0
        fitToWindow = true
        clearClickPosition()
    }

    // MARK: - Bounds Checking

    func isScaleValid(_ newScale: Double) -> Bool {
        return (minScale ... maxScale).contains(newScale)
    }

    // MARK: - Convenience

    var isAtDefaultScale: Bool {
        return abs(scale - 1.0) < 0.001
    }

    var isZoomed: Bool {
        return !isAtDefaultScale
    }

    var isPanned: Bool {
        return abs(offset.width) > 0.1 || abs(offset.height) > 0.1
    }
}
