//
//  SettingsView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import Photos
import CoreLocation
import UIKit

struct SettingsView: View {
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @StateObject private var locationManager = LocationPermissionManager()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettingsOpenError = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("권한") {
                    PermissionRow(
                        title: "사진 라이브러리",
                        description: "경로 복원을 위해 사진에 접근합니다",
                        status: photoLibraryStatus,
                        onTap: {
                            handlePhotoPermissionTap()
                        }
                    )
                    
                    LocationPermissionRow(
                        locationManager: locationManager,
                        onTap: {
                            handleLocationPermissionTap()
                        }
                    )
                }
                
                Section("진단") {
                    DiagnosticsRow(
                        title: "NSPhotoLibraryUsageDescription",
                        isOK: hasInfoPlistKey("NSPhotoLibraryUsageDescription")
                    )
                    DiagnosticsRow(
                        title: "NSLocationWhenInUseUsageDescription",
                        isOK: hasInfoPlistKey("NSLocationWhenInUseUsageDescription")
                    )
                }
                
                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                checkPermissions()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkPermissions()
                }
            }
            .alert("설정 앱을 열 수 없습니다", isPresented: $showingSettingsOpenError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("iOS 설정 앱을 열 수 없습니다. 수동으로 설정 앱에서 권한을 변경해주세요.")
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
    
    private func checkPermissions() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationManager.refreshStatus()
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                photoLibraryStatus = status
            }
        }
    }
    
    private func handlePhotoPermissionTap() {
        switch photoLibraryStatus {
        case .notDetermined:
            requestPhotoLibraryPermission()
        case .denied, .restricted:
            openAppSettings()
        case .authorized, .limited:
            openAppSettings()
        @unknown default:
            openAppSettings()
        }
    }
    
    private func handleLocationPermissionTap() {
        switch locationManager.status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            openAppSettings()
        case .authorizedWhenInUse, .authorizedAlways:
            openAppSettings()
        @unknown default:
            openAppSettings()
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            showingSettingsOpenError = true
            return
        }
        guard UIApplication.shared.canOpenURL(url) else {
            showingSettingsOpenError = true
            return
        }
        openURL(url)
    }
    
    private func hasInfoPlistKey(_ key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else { return false }
        if let string = value as? String {
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PHAuthorizationStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var statusBadge: some View {
        Group {
            switch status {
            case .authorized, .limited:
                Label("허용됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Label("거부됨", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .notDetermined:
                Label("요청 필요", systemImage: "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            @unknown default:
                Text("알 수 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LocationPermissionRow: View {
    @ObservedObject var locationManager: LocationPermissionManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("위치 정보")
                        .font(.body)
                    
                    Spacer()
                    
                    locationStatusBadge
                }
                
                Text("현재 위치를 지도에 표시하기 위해 필요합니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var locationStatusBadge: some View {
        Group {
            switch locationManager.status {
            case .authorizedWhenInUse, .authorizedAlways:
                Label("허용됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Label("거부됨", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .notDetermined:
                Label("요청 필요", systemImage: "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            @unknown default:
                Text("알 수 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        refreshStatus()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.status = manager.authorizationStatus
        }
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func refreshStatus() {
        status = locationManager.authorizationStatus
    }
}

struct DiagnosticsRow: View {
    let title: String
    let isOK: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Label(isOK ? "OK" : "Missing", systemImage: isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(isOK ? .green : .orange)
        }
    }
}
