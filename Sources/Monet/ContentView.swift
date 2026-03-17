//
//  ContentView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/1.
//

import AppKit
import SDWebImageSwiftUI
import SwiftUI

struct ContentView: View {
    @AppLog(category: "ContentView")
    private var logger

    @EnvironmentObject var appState: AppState

    @State private var currentImage: NSImage?
    @State private var scale: CGSize = .init(width: 1, height: 1)

    @State private var isNavBarVisible: Bool = true
    @State private var isCommandPressed: Bool = false

    @State private var window: NSWindow?

    @State private var showFileSelector = false

    // ScrollView的偏移状态，用来实现拖动查看图片的不同部分
    @State private var scrollViewOffset: CGSize = .zero
    @State private var lastDragPosition: CGSize = .zero

    @State private var scrollViewProxy: ScrollViewProxy? = nil

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .topLeading) {
                if isNavBarVisible {
                    VStack {
                        ScrollViewReader { scroller in

                            ScrollView {
                                LazyVStack {
                                    ForEach(Array(appState.imageFiles.enumerated()), id: \.offset) { index, imageURL in
                                        ImageThumbnailView(imageURL: imageURL, isSelected: appState.selectedImageIndex == index).id(index)
                                            .onTapGesture {
                                                loadImage(at: index)
                                            }
                                    }
                                }
                            }
                            .scrollIndicators(.never)
                            .padding(4)
                            .onAppear {
                                print("scrollViewProxy ....... init")
                                scrollViewProxy = scroller
                            }

                            // 确保浮动在主视图上方
                        }
                    }
                    .padding([.top], 28)
                    .frame(width: 128, height: (window?.frame.size.height ?? 720))
                    .background(Color.gray.opacity(0.6)) // 半透明背景
                    .zIndex(20)
                }

                ToolBarView(scale: scale, onTap: { actionID in
                    handleToolbarTap(actionID)
                })
                .zIndex(20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 32)

                HStack {
                    if let currentImage = currentImage {
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            // 使用 Image 组件加载图片，并设置其大小大于 ScrollView 的视图大小
                            Image(nsImage: currentImage)
                                .resizable()
                                .frame(width: currentImage.size.width * scale.width, height: currentImage.size.height * scale.height )
                                .scaleEffect(scale, anchor: .center)
                                .border(Color.red, width: 1)
                                .offset(x: scrollViewOffset.width, y: scrollViewOffset.height) // 通过偏移来控制图片的位置
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            // 计算拖动的偏移量，并更新状态
                                            let newOffset = CGSize(
                                                width: lastDragPosition.width + value.translation.width,
                                                height: lastDragPosition.height + value.translation.height
                                            )

                                            // 将新的偏移值设置到视图中
                                            scrollViewOffset = newOffset
                                        }
                                        .onEnded { _ in
                                            // 保存拖动结束时的位置
                                            lastDragPosition = scrollViewOffset
                                        }
                                )

                                .onTapGesture {
//                                    appState.appDelegate?.startShowWindowTitlebar()
                                }
                        }

                    } else {
                        HStack {
                            Button("Select Image File") {
                                showFileSelector = true
                            }
                            .fileImporter(isPresented: $showFileSelector, allowedContentTypes: [.png, .jpeg, .gif, .webP]) { result in
                                handleFileSelect(result)
                            }
                        }
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)
            }

            .ignoresSafeArea(.container)
            .onAppear(perform: appearHandler)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("open-image"))) { _ in
                loadImage(at: appState.selectedImageIndex)
            }
        }
    }

    func handleToolbarTap(_ id: ToolbarActionIdentifier) {
        print(id)
        switch id {
        case .toggleNav:
            isNavBarVisible.toggle()

        case .scaleMinis:
            scale.width -= 0.1
            scale.height -= 0.1

        case .scalePlus:
            scale.width += 0.1
            scale.height += 0.1

        case .showPrev:
            showPreviousImage()
        case .showNext:
            showNextImage()

        case .centerFill:
            centerFillImage()

        default:
            logger.warning("no action after tap toolbar")
        }
    }
    
    func centerFillImage() {
        guard let win = window, let image = currentImage else {
            logger.warning("no window or no image")
            return
        }
        let minScale = min( win.frame.width / image.size.width,  win.frame.height / image.size.height)
        
        self.scale = CGSize(width: minScale, height: minScale)
        
        self.scrollViewOffset.width = 0
        self.scrollViewOffset.height = 0
        
    }

    func handleFileSelect(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let fileUrl):
            // gain access to the directory
            let gotAccess = fileUrl.startAccessingSecurityScopedResource()
            if !gotAccess {
                logger.warning("not got access")
                return
            }
            // access the directory URL

            if let appDelegate = appState.appDelegate {
                appDelegate.loadImages(from: fileUrl)
                loadImage(at: appState.selectedImageIndex)
            } else {
                logger.warning("not appDelegate")
            }

        // release access
//            fileUrl.stopAccessingSecurityScopedResource()
        case .failure(let error):
            // handle error
            logger.error("error: \(error)")
        }
    }

    // 将全局坐标转换为局部坐标
    func convertGlobalToLocal(_ globalPoint: NSPoint, in geometry: GeometryProxy) -> CGPoint {
        let windowPoint = CGPoint(x: globalPoint.x, y: NSScreen.main?.frame.height ?? 0 - globalPoint.y) // 修正 Y 方向
        let localPoint = geometry.frame(in: .global).origin
        return CGPoint(x: windowPoint.x - localPoint.x, y: windowPoint.y - localPoint.y)
    }

    func appearHandler() {
        setupKeyEvents()
        loadImage(at: appState.selectedImageIndex)

        if let window = NSApplication.shared.windows.first {
            print("windwo \(window.title)-- \(window.frame.size)")
            self.window = window
        } else {
            print("not get window")
        }
    }

    private func loadImage(at index: Int) {
        print("loadImage ........")
        guard appState.imageFiles.indices.contains(index) else { return }
        // 获取图片 URL
        let url = appState.imageFiles[index]

        // 更新 AppState 中的 currentImageURL 和 selectedImageIndex
        appState.currentImageURL = url
        appState.selectedImageIndex = index
        scrollViewProxy?.scrollTo(index)

        // 尝试加载图像
        if let image = NSImage(contentsOf: url) {
            currentImage = image
        }
    }

    private func setupKeyEvents() {
        print("appear \(appState.selectedImageIndex)")

        // 监听 Command 键的按下事件
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.modifierFlags.contains(.command) {
                isCommandPressed = true
            } else {
                isCommandPressed = false
            }
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if isCommandPressed { // 只有按下 Command 键时才缩放
                let delta = event.scrollingDeltaY
//                let localPos = event.locationInWindow
//                if let window = NSApplication.shared.windows.first {
//                    self.anchorPoint = UnitPoint(
//                        x: localPos.x / window.frame.width,
//                        y: 1 - localPos.y / window.frame.height
//                    )
//                }
                scale.width += delta / 500
                scale.height += delta / 500 // 根据滚轮的滚动量进行缩放
                return nil // 防止滚动事件传递给其他组件
            }
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 124, 125: // Right Arrow
                showNextImage()
                return nil
            case 123, 126: // Left Arrow
                showPreviousImage()
                return nil
            default:
                return event
            }
        }
    }

    private func showNextImage() {
        if appState.selectedImageIndex < appState.imageFiles.count - 1 {
            loadImage(at: appState.selectedImageIndex + 1)
        }
    }

    private func showPreviousImage() {
        if appState.selectedImageIndex > 0 {
            loadImage(at: appState.selectedImageIndex - 1)
        }
    }
}

#Preview {
    ContentView()
}
