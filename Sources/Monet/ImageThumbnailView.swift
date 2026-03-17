//
//  ImageThumbnailView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/5.
//

import SwiftUI

struct ImageThumbnailView: View {
    let imageURL: URL
    let isSelected: Bool
    
    var body: some View {
        HStack {
            if let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 120, height: 90)
                    .scaledToFill()
                   
                    .border(isSelected ? Color.white : Color.clear, width: 2)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 120, height: 90)
                    .border(isSelected ? Color.blue : Color.clear, width: 4)
            }
        }
    }
}


