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
        }
        .modelContainer(for: [Route.self, PhotoRecord.self])
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            RouteListView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            ExifStampRootView()
                .tabItem {
                    Label("EXIF", systemImage: "text.below.photo")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
