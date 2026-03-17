//
//  NavigationFloatView.swift
//  Monet
//
//  Created by luke on 2025/11/8.
//

import SwiftUI

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let imageName: String
    let isActive: Bool
}

struct NavigationFloatView: View {
    // Mock data - replace with actual image list
    @State private var images: [ImageItem] = [
        ImageItem(imageName: "img1", isActive: false),
        ImageItem(imageName: "img2", isActive: true), // Current active image
        ImageItem(imageName: "img3", isActive: false),
        ImageItem(imageName: "img4", isActive: false),
        ImageItem(imageName: "img5", isActive: false),
        ImageItem(imageName: "img6", isActive: false),
        ImageItem(imageName: "img7", isActive: false),
    ]
    
    var body: some View {
        VStack(spacing: 12) {
        
            // Image list
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(images) { imageItem in
                        ImageNavigationCard(imageItem: imageItem)
                            .onTapGesture {
                                // Update active image
                                updateActiveImage(imageItem.id)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 400)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 5)
        .frame(width: 80)
    }
    
    private func updateActiveImage(_ selectedId: UUID) {
        images = images.map { image in
            ImageItem(
                imageName: image.imageName,
                isActive: image.id == selectedId
            )
        }
    }
}

struct ImageNavigationCard: View {
    let imageItem: ImageItem
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(imageItem.isActive ? Color.blue : Color.gray.opacity(0.5))
            .overlay(
                // Thumbnail placeholder - replace with actual image
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.7))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 16))
                    )
            )
            .overlay(
                // Active indicator
                RoundedRectangle(cornerRadius: 8)
                    .stroke(imageItem.isActive ? Color.blue : Color.clear, lineWidth: 3)
            )
            .frame(width: 56, height: 56)
            .shadow(
                color: imageItem.isActive ? Color.blue.opacity(0.5) : Color.clear,
                radius: 6,
                x: 0,
                y: 0
            )
    }
}

#Preview {
    HStack {
        NavigationFloatView()
        Spacer()
    }
    .background(Color.black)
}
