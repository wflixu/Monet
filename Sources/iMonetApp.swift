//
//  iMonetApp.swift
//  iMonet
//
//  Created by 李旭 on 2024/9/1.
//

import AppKit
import SwiftUI

/// A button that opens the app's Settings window via the app menu.
struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Preferences...") {
            openWindow(id: Constants.settingsWindowID)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

@main
struct iMonetApp: App {
    @AppLog(category: "iMonetApp")
    private var logger

    // 设置 App Delegate 以响应 open file 请求
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var appState = AppState()

    init() {
        logger.info("app init .....")
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        Window("iMonet", id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.storeManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    appDelegate.openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Print") {
                    NotificationCenter.default.post(name: Notification.Name("print-image"), object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                OpenSettingsButton()
            }
#if DEBUG
            CommandMenu("Debug") {
                Button("Force Show Purchase Prompt") {
                    UsageTracker.forceReadyForPrompt()
                    appState.storeManager.isPurchased = false
                    NotificationCenter.default.post(name: .showPurchasePrompt, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Reset Purchase State") {
                    UsageTracker.resetAll()
                    appState.storeManager.isPurchased = false
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
#endif
        }

        SettingsWindow(appState: appState, onAppear: {})
            .restorationBehavior(.disabled)
    }
}

// AppDelegate 负责处理文件打开请求
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppState")
    private var logger

    private var appState: AppState?

    func applicationWillFinishLaunching(_ notification: Notification) {
        logger.info("---- app will finish launch")
        guard let appState else {
            logger.warning("Missing app state in applicationWillFinishLaunching")
            return
        }

        // assign the delegate to the shared app state
        appState.assignAppDelegate(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("applicationDidFinishLaunching  .......")
        UsageTracker.recordLaunch()
        Task {
            await appState?.storeManager.loadProducts()
            await appState?.storeManager.verifyEntitlement()
        }
        Task.detached { [appState] in
            await appState?.storeManager.listenForTransactions()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 当最后一个窗口关闭时，终止应用
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("application open urls")
        guard let currentImageURL = urls.first else {
            logger.warning("no url in urls")
            return
        }
        logger.info("Received file URL: \(currentImageURL)")
        loadImages(from: currentImageURL)
        NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("applicationShouldTerminate")
        return .terminateNow
    }

    /// Assigns the app state to the delegate.
    func assignAppState(_ appState: AppState) {
        guard self.appState == nil else {
            logger.warning("Multiple attempts made to assign app state")
            return
        }
        self.appState = appState
    }

    func loadImages(from url: URL) {
        logger.info("loadImages from: \(url.path)")
        guard let appState else { return }

        // Always load the selected image first
        appState.imageFiles = [url]
        appState.selectedImageIndex = 0
        appState.currentImageURL = url

        guard UserDefaults.standard.object(forKey: "showCurDirImg") as? Bool ?? true else { return }

        let directory = url.deletingLastPathComponent()

        // Try existing bookmark access
        if indexFolder(directory, currentURL: url) {
            logger.info("Indexed via bookmark: \(directory.path)")
            return
        }

        // No permission — request via NSOpenPanel
        logger.info("No access to \(directory.path), prompting user...")
        promptFolderPermission(for: directory, currentURL: url)
    }

    /// Request folder access permission via NSOpenPanel presented as a sheet on the main window.
    func promptFolderPermission(for directory: URL, currentURL: URL) {
        guard let appState else { return }
        guard let window = NSApplication.shared.windows.first(where: { $0.title == "iMonet" }) else {
            logger.warning("No iMonet window found for sheet")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.message = String(localized: "允许 iMonet 访问此文件夹以浏览所有图片")
        panel.prompt = String(localized: "允许")

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = panel.url else { return }

            let gotAccess = selectedURL.startAccessingSecurityScopedResource()
            guard gotAccess else { return }

            if !appState.dirs.contains(selectedURL) {
                appState.dirs.append(selectedURL)
                appState.storeBookmarkData()
            }

            self.indexFolder(selectedURL, currentURL: currentURL, keepAccess: true)
        }
    }

    /// Open a folder or image file via NSOpenPanel, replacing current window content.
    func openFolder() {
        guard let appState else { return }
        guard let window = NSApplication.shared.windows.first(where: { $0.title == "iMonet" }) else {
            logger.warning("No iMonet window found for open panel")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "选择文件夹或图片")
        panel.prompt = String(localized: "打开")

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = panel.url else { return }

            let isDirectory = (try? selectedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDirectory {
                let gotAccess = selectedURL.startAccessingSecurityScopedResource()
                guard gotAccess else { return }

                if !appState.dirs.contains(selectedURL) {
                    appState.dirs.append(selectedURL)
                    appState.storeBookmarkData()
                }

                self.indexFolder(selectedURL, currentURL: selectedURL, keepAccess: true)
                selectedURL.stopAccessingSecurityScopedResource()
                NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
            } else {
                self.loadImages(from: selectedURL)
                NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
            }
        }
    }

    /// Scan a directory for images.
    /// - Parameter keepAccess: If `false` (default), the method calls `startAccessingSecurityScopedResource()`
    ///   and manages the scope lifecycle internally. If `true`, the caller already has access established
    ///   (via NSOpenPanel or Full Disk Access) and the security-scope check is skipped.
    @discardableResult
    func indexFolder(_ directory: URL, currentURL: URL, keepAccess: Bool = false) -> Bool {
        guard let appState else { return false }

        let startedHere = !keepAccess && directory.startAccessingSecurityScopedResource()
        if !keepAccess {
            guard startedHere else { return false }
        }
        defer {
            if startedHere { directory.stopAccessingSecurityScopedResource() }
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            logger.warning("Cannot read directory: \(directory.path)")
            return false
        }

        let imageFiles = files
            .filter { Constants.supportedImageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !imageFiles.isEmpty else { return false }

        appState.imageFiles = imageFiles
        appState.selectedImageIndex = imageFiles.firstIndex(of: currentURL) ?? 0
        appState.currentImageURL = imageFiles[appState.selectedImageIndex]
        logger.info("Indexed \(imageFiles.count) images in folder")

        return true
    }
}
