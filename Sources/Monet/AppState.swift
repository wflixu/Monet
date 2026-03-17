//
//  AppState.swift
//  Monet
//
//  Created by 李旭 on 2024/9/5.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @AppLog(category: "AppState")
    private var logger

    @Published var currentImageURL: URL?
    @Published var imageFiles: [URL] = []
    @Published var selectedImageIndex: Int = 0

    @Published var settingsNavigationIdentifier: SettingsNavigationIdentifier = .general
    // Permission
    @Published var dirs: [URL] = []
    @Published var showCurDirImg: Bool = false

    /// Manager for app permissions.
    private(set) lazy var permissionsManager = PermissionsManager(appState: self)

    /// The app's delegate.
    private(set) weak var appDelegate: AppDelegate?

    /// The window that contains the settings interface.
    private(set) weak var settingsWindow: NSWindow?

    init() {
        let defaults = UserDefaults.standard
        if let storedValue = defaults.object(forKey: "showCurDirImg") as? Bool {
            self.showCurDirImg = storedValue
            if(self.showCurDirImg) {
                self.restoreBookmarkData()
            }
        } else {
            self.showCurDirImg = false
        }
    }

    func storeBookmarkData() {
        var bookmarkArray: [Data] = []
        for url in dirs {
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmarkArray.append(bookmarkData)
            } catch {
                logger.warning("Failed to create bookmark for \(url): \(error)")
            }
        }

        UserDefaults.standard.set(bookmarkArray, forKey: Constants.dirBookmarkDataKey)
    }

    func restoreBookmarkData() {
        guard let bookmarkArray = UserDefaults.standard.array(forKey: Constants.dirBookmarkDataKey) as? [Data] else {
            logger.warning("userDefaults get data fail")
            return
        }

        var urls: [URL] = []

        for bookmarkData in bookmarkArray {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    logger.warning("Bookmark is stale, need to reselect folder. \(url.path)")
                } else {
                    if url.startAccessingSecurityScopedResource() {
                        urls.append(url)
                    } else {
                        logger.warning("Failed to access security-scoped resource for \(url.path).")
                    }
                }
            } catch {
                logger.error("Failed to resolve bookmark: \(error)")
            }
        }

        dirs = urls
    }

    /// Assigns the app delegate to the app state.
    func assignAppDelegate(_ appDelegate: AppDelegate) {
        guard self.appDelegate == nil else {
            logger.warning("Multiple attempts made to assign app delegate")
            return
        }
        self.appDelegate = appDelegate
    }

    /// Assigns the settings window to the app state.
    func assignSettingsWindow(_ settingsWindow: NSWindow) {
        guard self.settingsWindow == nil else {
            logger.warning("Multiple attempts made to assign settings window")
            return
        }
        self.settingsWindow = settingsWindow
    }

    /// Activates the app and sets its activation policy to the given value.
    func activate(withPolicy policy: NSApplication.ActivationPolicy) {
        // store whether the app has previously activated inside an internal
        // context to keep it isolated
        enum Context {
            nonisolated(unsafe) static let hasActivated = ObjectAssociation<Bool>()
        }

        func activate() {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                NSRunningApplication.current.activate(from: frontApp)
            } else {
                NSApp.activate()
            }
            NSApp.setActivationPolicy(policy)
        }

        if Context.hasActivated[self] == true {
            activate()
        } else {
            Context.hasActivated[self] = true
            logger.debug("First time activating app, so going through Dock")
            // hack to make sure the app properly activates for the first time
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activate()
            }
        }
    }
}
