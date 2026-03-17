//
//  Constants.swift
//  Monet
//
//  Created by 李旭 on 2024/9/11.
//

import Foundation

enum Constants {
    /// The version string in the app's bundle.
    static let appVersion = Bundle.main.versionString!

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    // swiftlint:enable force_unwrapping

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"

    static let dirBookmarkDataKey = "PICASA_DIRS"
}
