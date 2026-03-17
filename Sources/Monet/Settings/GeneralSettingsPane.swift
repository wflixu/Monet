//
//  GeneralSettingsPane.swift
//  Monet
//
//  Created by 李旭 on 2024/9/12.
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @AppLog(category: "View-GeneralSettingsPane")
    private var logger

    @EnvironmentObject var appState: AppState

    @State private var exploreDir = false
    @State private var showDirImporter = false

    @AppStorage("showCurDirImg")
    private var showCurDirImg: Bool = false

    private var permissionDirs: [PermissionDir] {
        return appState.dirs.map { url in
            PermissionDir(url: url)
        }
    }

    var body: some View {
        Form {
            Section {
                launchAtLogin
            }
            SectionPermission
//            Section {
//                iceBarOptions
//            }
//            Section {
//                showOnClick
//                showOnHover
//                showOnScroll
//            }
//            Section {
//                autoRehideOptions
//            }
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        LaunchAtLogin.Toggle()
    }

    @ViewBuilder
    private var SectionPermission: some View {
        Section {
            Toggle(isOn: $showCurDirImg) {
                Text("Explore dir")
            }

            if showCurDirImg {
                HStack {
                    Spacer()
                  
                    Button(action: {
                        showDirImporter = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }.buttonStyle(PlainButtonStyle())
                }.padding([.leading, .trailing], 16)

                List {
                    ForEach(Array(permissionDirs.enumerated()), id: \.element.path) { index, dir in
                        HStack {
                            Text(dir.path)
                                .font(.title3)
                            Spacer()
                            Button(action: {
                                // 按钮点击
                                appState.dirs.remove(at: index)
                                appState.storeBookmarkData();
                            }) {
                                Image(systemName: "delete.left")
                            }

                        }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .onChange(of: showCurDirImg, {
            appearAction()
        })

        .fileImporter(
            isPresented: $showDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
                case .success(let dirs):
                    if let dir = dirs.first {
                        let gotaccess = dir.startAccessingSecurityScopedResource()
                        if gotaccess {
                            appState.dirs.append(dir)
                            appState.storeBookmarkData()
                        } else {
                            logger.warning("not get access dir: \(dir.path)")
                        }
                    }
                case .failure(let error):
                    // handle error
                    print(error)
            }
        }
    }

    func appearAction() {
        appState.showCurDirImg = showCurDirImg
        if showCurDirImg {
            appState.restoreBookmarkData()
        }
    }
}

#Preview {
    GeneralSettingsPane()
}
