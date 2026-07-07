//
//  Constants.swift
//  iMonet
//
//  Created by 李旭 on 2024/9/11.
//

import Foundation

enum Constants {
    /// The marketing version (e.g. "2.0.0").  Reads from CFBundleShortVersionString;
    /// falls back when the Info.plist variable is not expanded (SPM / swift run).
    static let appVersion: String = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        // Xcode substitutes $(MARKETING_VERSION) at build time; SPM leaves the literal.
        if raw.isEmpty || raw.hasPrefix("$(") { return "2.0.0" }
        return raw
    }()

    /// The build version (e.g. "20260604001").  Reads from CFBundleVersion;
    /// falls back when the Info.plist variable is not expanded.
    static let buildVersion: String = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if raw.isEmpty || raw.hasPrefix("$(") { return "20260604001" }
        return raw
    }()

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    // swiftlint:enable force_unwrapping

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"

    static let dirBookmarkDataKey = "PICASA_DIRS"

    /// Supported image file extensions.
    static let supportedImageExtensions = ["png", "jpg", "jpeg", "gif", "webp"]
}
