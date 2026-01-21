//
//  SettingsView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import Photos
import CoreLocation

struct SettingsView: View {
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack {
            List {
                Section("권한") {
                    PermissionRow(
                        title: "사진 라이브러리",
                        description: "경로 복원을 위해 사진에 접근합니다",
                        status: photoLibraryStatus,
                        action: {
                            requestPhotoLibraryPermission()
                        }
                    )
                    
                    LocationPermissionRow()
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
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                photoLibraryStatus = status
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PHAuthorizationStatus
    let action: () -> Void
    
    var body: some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if status != .authorized && status != .limited {
                action()
            } else {
                // 설정 앱 열기
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
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
    @StateObject private var locationManager = LocationPermissionManager()
    
    var body: some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if locationManager.status != .authorizedWhenInUse && locationManager.status != .authorizedAlways {
                // 설정 앱 열기
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } else {
                // 설정 앱 열기
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
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
        status = locationManager.authorizationStatus
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}

