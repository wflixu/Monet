//
//  PermissionsManager.swift
//  Monet
//
//  Created by 李旭 on 2024/9/11.
//

import Combine
import Foundation

/// A type that manages the permissions of the app.
class PermissionsManager: ObservableObject {
    /// A Boolean value that indicates whether the app has been
    /// granted all permissions.
    @Published var hasPermission: Bool = false

    @Published var dirs: [URL] = []

    private(set) weak var appState: AppState?

  

    init(appState: AppState) {
        self.appState = appState
       
    }

}
