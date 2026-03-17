//
//  MenuBarView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/12.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    var body: some View {
        VStack {
            Button(action: actionSetting) {
                Image(systemName: "gear")
                Text("Settings")
            }
            .keyboardShortcut(",", modifiers: [.command])
            
            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text("Quit")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
    
    private func actionSetting() {
        openWindow(id: Constants.settingsWindowID)
    }
    
    private func actionQuit() {
        Task {
            try await Task.sleep(nanoseconds: UInt64(1.0 * 1e9))
            NSApplication.shared.terminate(self)
        }
    }
}

#Preview {
    MenuBarView()
}
