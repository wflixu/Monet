import SwiftData
import SwiftUI
import AppKit

struct ZoomableImageView: View {
    @EnvironmentObject var viewState: ViewState
    @State private var dragStartOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image("sample")
                .resizable()
                .aspectRatio(nil, contentMode: .fit)
                .scaleEffect(viewState.scale, anchor: viewState.anchor)
                .offset(viewState.offset)
                
                .contentShape(Rectangle()) // Make entire image clickable
                .background(
                    GeometryReader { imageGeometry in
                        Color.clear
                            .onAppear {
                                viewState.imageSize = imageGeometry.size
                            }
                            .onChange(of: imageGeometry.size) { _, newSize in
                                viewState.imageSize = newSize
                            }
                    }
                )
                .onTapGesture { location in
                    // Store the click position relative to the image
                    viewState.recordClickPosition(location)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 计算新的偏移量：起始偏移量 + 当前拖动偏移量
                            let newOffset = CGSize(
                                width: dragStartOffset.width + value.translation.width,
                                height: dragStartOffset.height + value.translation.height
                            )

                            // 确保偏移量是有效值
                            guard newOffset.width.isFinite && newOffset.height.isFinite else {
                                return
                            }

                            viewState.setPan(offset: newOffset)
                        }
                        .onEnded { _ in
                            // 更新起始偏移量为当前偏移量，以便下次拖动从此位置开始
                            // 确保保存的偏移量是有效的
                            if viewState.offset.width.isFinite && viewState.offset.height.isFinite {
                                dragStartOffset = viewState.offset
                            }
                        }
                )
                .background(
                    ScrollWheelMonitor(viewState: viewState, viewBounds: geometry.size)
                )
                .onAppear {
                    // 打印几何尺寸用于调试
                    print("ZoomableImageView appeared with size: \(geometry.size)")
                }
               
        }
    }
    
}

struct ScrollWheelMonitor: NSViewRepresentable {
    @ObservedObject var viewState: ViewState
    let viewBounds: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        setupScrollWheelMonitor(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }

    private func setupScrollWheelMonitor(view: NSView) {
        // 监听滚轮事件
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            return self.handleScrollWheel(event: event) ?? event
        }
    }

    private func handleScrollWheel(event: NSEvent) -> NSEvent? {
        // 检查是否按下了 Command 键
        guard event.modifierFlags.contains(.command) else {
            return event
        }


        // 计算缩放因子
        let scrollDelta = event.scrollingDeltaY
        let zoomFactor: Double

        if scrollDelta > 0 {
            // 向上滚动，放大
            zoomFactor = 1.1
        } else {
            // 向下滚动，缩小
            zoomFactor = 0.9
        }

        // 使用上次点击位置作为缩放中心，使用图像尺寸作为边界
        viewState.zoom(factor: zoomFactor)

        return event
    }
}

#Preview {
    ZoomableImageView()
        .background(Color.gray)
}
