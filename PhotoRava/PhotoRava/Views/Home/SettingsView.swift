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
                        description: "선택한 사진의 촬영 시간과 위치를 읽어 경로 지도, 타임라인, EXIF 결과를 만듭니다.",
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
                        title: "사진 권한 안내 문구",
                        detail: "iOS가 사진 접근 이유를 보여줄 준비가 되어 있는지 확인합니다.",
                        technicalName: "NSPhotoLibraryUsageDescription",
                        isOK: hasInfoPlistKey("NSPhotoLibraryUsageDescription")
                    )
                    DiagnosticsRow(
                        title: "위치 권한 안내 문구",
                        detail: "iOS가 위치 접근 이유를 보여줄 준비가 되어 있는지 확인합니다.",
                        technicalName: "NSLocationWhenInUseUsageDescription",
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
            .navigationBarTitleDisplayMode(.inline)
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.body)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(statusMessage)
    }
    
    private var statusBadge: some View {
        Group {
            switch status {
            case .authorized:
                Label("허용됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .limited:
                Label("일부 허용", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Label("설정 필요", systemImage: "xmark.circle.fill")
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

    private var statusMessage: String {
        switch status {
        case .authorized:
            return "사진 분석과 결과 저장에 필요한 접근이 허용되어 있습니다."
        case .limited:
            return "일부 사진만 허용되어 있습니다. 더 많은 사진을 분석하려면 탭해 접근 범위를 조정하세요."
        case .denied, .restricted:
            return "탭하면 iOS 설정에서 사진 접근을 다시 허용할 수 있습니다."
        case .notDetermined:
            return "탭하면 iOS 권한 요청이 열립니다."
        @unknown default:
            return "권한 상태를 확인할 수 없습니다. 탭해 iOS 설정을 확인하세요."
        }
    }
}

struct LocationPermissionRow: View {
    @ObservedObject var locationManager: LocationPermissionManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("위치 정보")
                        .font(.body)
                    
                    Spacer()
                    
                    locationStatusBadge
                }
                
                Text("지도에서 내 위치를 확인할 때 사용합니다. 경로는 선택한 사진의 위치 정보로 만듭니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(locationStatusMessage)
    }
    
    private var locationStatusBadge: some View {
        Group {
            switch locationManager.status {
            case .authorizedWhenInUse, .authorizedAlways:
                Label("허용됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Label("설정 필요", systemImage: "xmark.circle.fill")
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

    private var locationStatusMessage: String {
        switch locationManager.status {
        case .authorizedWhenInUse, .authorizedAlways:
            return "지도에서 현재 위치를 표시할 수 있습니다."
        case .denied, .restricted:
            return "탭하면 iOS 설정에서 위치 접근을 다시 허용할 수 있습니다."
        case .notDetermined:
            return "탭하면 iOS 권한 요청이 열립니다."
        @unknown default:
            return "권한 상태를 확인할 수 없습니다. 탭해 iOS 설정을 확인하세요."
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
    let detail: String
    let technicalName: String
    let isOK: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(technicalName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Label(isOK ? "준비됨" : "확인 필요", systemImage: isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(isOK ? .green : .orange)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
