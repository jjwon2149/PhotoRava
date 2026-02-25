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
    @Environment(\.modelContext) private var modelContext
    
    // User Preferences (Stored in AppStorage)
    @AppStorage("distanceUnit") private var distanceUnit: String = "km"
    @AppStorage("mapStyle") private var mapStyle: String = "standard"
    
    @State private var showingSettingsOpenError = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteSuccess = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    Text("권한 설정")
                } footer: {
                    Text("권한을 변경하려면 각 항목을 탭하여 시스템 설정으로 이동하세요.")
                }
                
                Section("개인 설정") {
                    Picker(selection: $distanceUnit) {
                        Text("킬로미터 (km)").tag("km")
                        Text("마일 (mile)").tag("mile")
                    } label: {
                        Label("거리 단위", systemImage: "ruler")
                    }
                    
                    Picker(selection: $mapStyle) {
                        Text("표준").tag("standard")
                        Text("위성").tag("satellite")
                        Text("하이브리드").tag("hybrid")
                    } label: {
                        Label("지도 스타일", systemImage: "map")
                    }
                }
                
                Section("데이터 관리") {
                    Button(role: .destructive) {
                        showingDeleteAllAlert = true
                    } label: {
                        Label("모든 경로 데이터 삭제", systemImage: "trash")
                    }
                }
                
                Section("시스템 진단") {
                    DiagnosticsRow(
                        title: "사진 접근 설명 설정",
                        isOK: hasInfoPlistKey("NSPhotoLibraryUsageDescription")
                    )
                    DiagnosticsRow(
                        title: "위치 정보 설명 설정",
                        isOK: hasInfoPlistKey("NSLocationWhenInUseUsageDescription")
                    )
                }
                
                Section("지원 및 정보") {
                    Button {
                        // 실제 앱 스토어 ID로 교체 필요
                        openURL(URL(string: "https://apps.apple.com/app/id123456789")!)
                    } label: {
                        HStack {
                            Label("앱 평가하기", systemImage: "star")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        let email = "support@photorava.com"
                        if let url = URL(string: "mailto:\(email)") {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Label("문의하기", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    HStack {
                        Label("버전", systemImage: "info.circle")
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
            .alert("모든 데이터 삭제", isPresented: $showingDeleteAllAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    deleteAllRoutes()
                }
            } message: {
                Text("기기에 저장된 모든 경로와 사진 기록이 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("삭제 완료", isPresented: $showingDeleteSuccess) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("모든 경로 데이터가 삭제되었습니다.")
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
        default:
            openAppSettings()
        }
    }
    
    private func handleLocationPermissionTap() {
        switch locationManager.status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
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
    
    private func deleteAllRoutes() {
        do {
            try modelContext.delete(model: Route.self)
            try modelContext.delete(model: PhotoRecord.self)
            try modelContext.save()
            showingDeleteSuccess = true
        } catch {
            print("Failed to delete all routes: \(error)")
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PHAuthorizationStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                statusBadge
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var statusBadge: some View {
        Group {
            switch status {
            case .authorized, .limited:
                Text("허용됨")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            case .denied, .restricted:
                Text("거부됨")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            case .notDetermined:
                Text("설정 필요")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct LocationPermissionRow: View {
    @ObservedObject var locationManager: LocationPermissionManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("위치 정보")
                        .font(.body)
                    
                    Text("현재 위치를 지도에 표시하기 위해 필요합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                locationStatusBadge
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var locationStatusBadge: some View {
        Group {
            switch locationManager.status {
            case .authorizedWhenInUse, .authorizedAlways:
                Text("허용됨")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            case .denied, .restricted:
                Text("거부됨")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            case .notDetermined:
                Text("설정 필요")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            @unknown default:
                EmptyView()
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
