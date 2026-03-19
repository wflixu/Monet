//
//  SettingsView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationTitle("settings")
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $appState.settingsNavigationIdentifier) {
            Section {
                ForEach(SettingsNavigationIdentifier.allCases, id: \.self) { identifier in
                    sidebarItem(for: identifier)
                }
            } header: {
                HStack {
                    Image("Monet")
                        .resizable()
                        .frame(width: 42, height: 42)

                    Text("Monet")
                        .font(.system(size: 30, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 8)
            }
            .collapsible(false)
        }
        .navigationSplitViewColumnWidth(210)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.settingsNavigationIdentifier {
        case .general:
            GeneralSettingsPane()
//        case .hotkeys:
//            HotkeysSettingsPane()
//        case .advanced:
//            AdvancedSettingsPane()
//        case .updates:
//            UpdatesSettingsPane()
        case .about:
            AboutSettingsPane()
        default:
            HStack {
                Text("detailView")
            }
        }
    }

    @ViewBuilder
    private func sidebarItem(for identifier: SettingsNavigationIdentifier) -> some View {
        Label {
            Text(identifier.localized)
                .font(.title3)
                .padding(.leading, 2)
        } icon: {
            icon(for: identifier).view
                .foregroundStyle(.primary)
                .imageScale(.small)
        }
        .frame(height: 32)
    }

    private func icon(for identifier: SettingsNavigationIdentifier) -> IconResource {
        switch identifier {
        case .general: .systemSymbol("gearshape")
        case .hotkeys: .systemSymbol("keyboard")
        case .advanced: .systemSymbol("gearshape.2")
        case .updates: .systemSymbol("arrow.triangle.2.circlepath.circle")
        case .about: .systemSymbol("gearshape")
        }
    }
}
