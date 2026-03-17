//
//  InfoBarView.swift
//  Monet
//
//  Created by luke on 2025/11/8.
//

import SwiftUI

struct InfoBarView: View {
    @State private var imageTitle = "Sample Image"
    @State private var imageInfo = "1920x1080 • 2.4MB"
    @EnvironmentObject var viewState: ViewState
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("image size: (x: \(viewState.imageSize.width), y: \(viewState.imageSize.height))")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("image scale: (\(viewState.scale))")
                    .foregroundColor(.green)
                Text("image anchor: (x: \(viewState.anchor.x), y: \(viewState.anchor.y))")
                    .foregroundColor(.red)
                Text("image offset: (x: \(viewState.offset.width), y: \(viewState.offset.height))")
                    .foregroundColor(.white)
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.2), value: viewState.clickPosition)
        
            Spacer()
            
            // Display click position if available
            if let clickPosition = viewState.clickPosition {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        
                    Text("Click: (x: \(Int(clickPosition.x)), y: \(Int(clickPosition.y)))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.2), value: viewState.clickPosition)
            }
           
            Spacer()
            
            Button(action: {
                // Close or back action
                viewState.setPan(offset: .zero)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.title2)
            }
            
            Button(action: {
                // More options
            }) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.3)) // Red tint for top info bar
                .background(.ultraThinMaterial)
        )
        .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    InfoBarView()
        .environmentObject(ViewState())
        .background(Color.black)
}
