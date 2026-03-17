//
//  AboutSettingsPane.swift
//  Monet
//
//  Created by 李旭 on 2024/9/13.
//

import SwiftUI

struct AboutSettingsPane: View {
    @Environment(\.openURL) private var openURL
    @State private var frame = CGRect.zero

    private var contributeURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/wflixu/Monet")!
    }

    private var issuesURL: URL {
        contributeURL.appendingPathComponent("issues")
    }

    private var minFrameDimension: CGFloat {
        min(frame.width, frame.height)
    }

    var body: some View {
        HStack {
            Spacer()
            Image("Monet")
                .resizable()
                .frame(width: 200, height: 200)
           
            VStack(alignment: .leading) {
                Text("Monet")
                    .font(.largeTitle)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("Version")
                    Text(Constants.appVersion)
                }
                .font(.system(size: minFrameDimension / 30))
                .foregroundStyle(.secondary)
            }
            .fontWeight(.medium)
            .padding([.vertical, .trailing])
            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .bottomBar {
            HStack {
                Button("Quit Monet") {
                    NSApp.terminate(nil)
                }
                Spacer()

                Button("Contribute") {
                    openURL(contributeURL)
                }
                Button("Report a Bug") {
                    openURL(issuesURL)
                }
            }
            .padding()
        }
    }
}

extension View {
    /// Adds the given view as a bottom bar to the current view.
    ///
    /// - Parameter content: A view to be added as a bottom bar to the current view.
    func bottomBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                content()
            }
        }
    }
}
