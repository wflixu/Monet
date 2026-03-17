//
//  LayoutView.swift
//  Monet
//
//  Created by luke on 2025/11/8.
//

import SwiftUI

struct LayoutView: View {
    @StateObject private var viewState = ViewState()
    @State private var showTopBar = true
    @State private var showSideBar = true
    @State private var showBottomBar = true
    @State private var scale: CGSize = .init(width: 1, height: 1)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - ZoomableImageView occupies full space
                ZoomableImageView()
                    .background(Color.black)
                    .environmentObject(viewState)
                
                // Top floating information bar - full width
                if showTopBar {
                    VStack {
                        InfoBarView()
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                    .padding(.top, 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .environmentObject(viewState)
                }
                
                // Left floating navigation view
                if showSideBar {
                    HStack {
                        NavigationFloatView()
                            .frame(width: 80, height: viewState.imageSize.height)
                        Spacer()
                    }
                    .padding(.leading, 0)
                    .padding(.vertical, 0) // Avoid overlapping with top/bottom bars
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                // Bottom floating toolbar - full width
                if showBottomBar {
                    VStack {
                        Spacer()
                        ToolBarView(scale: scale, onTap: handleToolbarTap)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                // 打印容器的尺寸
                print("LayoutView appeared with size: \(geometry.size)")
            }
        }
        .background(Color.black)
    }

    func handleToolbarTap(_ id: ToolbarActionIdentifier) {
        print(id)
        switch id {
        case .toggleNav:
            showSideBar.toggle()
        case .toggleInfo:
            showTopBar.toggle()
        case .scaleMinis:
            scale.width = max(0.1, scale.width - 0.1)
            scale.height = max(0.1, scale.height - 0.1)
        case .scalePlus:
            scale.width += 0.1
            scale.height += 0.1
        case .showPrev:
            // TODO: Implement previous image
            break
        case .showNext:
            // TODO: Implement next image
            break
        case .centerFill:
            scale = .init(width: 1, height: 1)
        }
    }
}

#Preview {
    LayoutView()
}
