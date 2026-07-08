//
//  ToolBarView.swift
//  iMonet
//
//  Created by 李旭 on 2024/9/15.
//

import AppKit
import SwiftUI

struct ToolBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState

    let scale: CGSize

    let onTap: (_ actionID: ToolbarActionIdentifier) -> Void
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    var scaleFormated: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        if let formattedString = formatter.string(from: NSNumber(value: scale.width)) {
            return formattedString
        } else {
            return ""
        }
    }

    var indexFormated: String {
        return "\(appState.selectedImageIndex + 1)/\(appState.imageFiles.count)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                self.onTap(.scaleMinis)
            }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Zoom out")

            Text(scaleFormated).foregroundStyle(.primary)
                .monospacedDigit()
                .frame(minWidth: 44)

            Button(action: {
                self.onTap(.scalePlus)
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Zoom in")

            Button(action: {
                self.onTap(.actualSize)
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Actual size")

            Button(action: {
                self.onTap(.centerFill)
            }) {
                Image(systemName: "rectangle.center.inset.filled")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Fit to window")

            Button(action: {
                self.onTap(.showPrev)
            }) {
                Image(systemName: "chevron.left.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Previous picture")

            Text(indexFormated).foregroundStyle(.primary)

            Button(action: {
                self.onTap(.showNext)
            }) {
                Image(systemName: "chevron.right.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Next picture")

            Divider()

            Button(action: {
                self.onTap(.rotateLeft)
            }) {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Rotate left")

            Button(action: {
                self.onTap(.rotateRight)
            }) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Rotate right")

            Button(action: {
                self.onTap(.deleteImage)
            }) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Delete Picture")

            Divider()

            Button(action: {
                self.onTap(.toggleNav)
            }) {
                Image(systemName: "square.leadingthird.inset.filled")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Toggle navigation")

            Button(action: {
                self.onTap(.toggleInfo)
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Picture info")
        }
        .padding([.leading, .trailing], 10)
        .padding([.top, .bottom], 8)
        .frame(height: 42)
        .background(colorScheme == .dark ? Color.gray.opacity(0.6) : Color.white.opacity(1))
        .clipShape(.rect(cornerRadius: 4))
        .shadow(radius: 2)
        .overlay(
            Rectangle()
                .fill(Color.clear)
                .allowsHitTesting(false)
                .onHover { hovering in
                    if hovering {
                        onHoverEnter?()
                    } else {
                        onHoverExit?()
                    }
                }
        )
    }
}

enum ToolbarActionIdentifier: String, Hashable {
    case scaleMinis
    case scalePlus
    case actualSize
    case showPrev
    case showNext
    case toggleNav
    case toggleInfo
    case centerFill
    case rotateLeft
    case rotateRight
    case deleteImage
}
