//
//  PhotoRavaApp.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData

@main
struct PhotoRavaApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    if #available(iOS 26.0, *) {
                        LocalAIService.shared.prewarmIfNeeded()
                    }
                }
        }
        .modelContainer(for: [Route.self, PhotoRecord.self])
    }
}

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            RouteListView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppState.Tab.home)
            
            ExifStampRootView()
                .tabItem {
                    Label("EXIF", systemImage: "text.below.photo")
                }
                .tag(AppState.Tab.exif)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppState.Tab.settings)
        }
    }
}
