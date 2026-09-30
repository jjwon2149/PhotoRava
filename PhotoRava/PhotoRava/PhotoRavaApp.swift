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
    init() {
        AdMobService.shared.startIfConfigured()
    }

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
    @Environment(\.modelContext) private var modelContext
    @State private var isRouteRecoveryComplete = false
    
    var body: some View {
        Group {
            if isRouteRecoveryComplete {
                TabView(selection: $appState.selectedTab) {
                    RouteListView()
                        .tabItem {
                            Label("경로", systemImage: "map.fill")
                        }
                        .tag(AppState.Tab.home)

                    ExifStampRootView()
                        .tabItem {
                            Label("EXIF", systemImage: "text.below.photo")
                        }
                        .tag(AppState.Tab.exif)

                    SettingsView()
                        .tabItem {
                            Label("설정", systemImage: "gearshape")
                        }
                        .tag(AppState.Tab.settings)
                }
            } else {
                ProgressView("저장된 경로 확인 중…")
            }
        }
        .task {
            do {
                try await RouteDerivedDataRecoveryService.shared.recoverOptimizedRoutes(
                    in: modelContext.container
                )
                isRouteRecoveryComplete = true
            } catch is CancellationError {
                // A later view task will retry before the route list is shown.
            } catch {
                isRouteRecoveryComplete = true
            }
        }
    }
}
