//
//  RouteMapView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: Route
    private let onBack: (() -> Void)?
    @StateObject private var viewModel: RouteMapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = .medium
    
    init(route: Route, onBack: (() -> Void)? = nil) {
        self.route = route
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: RouteMapViewModel(route: route))
    }
    
    var body: some View {
        ZStack {
            // Full screen map
            Map(position: $viewModel.cameraPosition) {
                // Route polyline
                if !viewModel.coordinates.isEmpty {
                    MapPolyline(coordinates: viewModel.coordinates)
                        .stroke(.blue, lineWidth: 4)
                }
                
                // Start marker
                if let start = viewModel.coordinates.first {
                    Annotation("출발", coordinate: start) {
                        ZStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 30, height: 30)
                            
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 30, height: 30)
                            
                            Text("S")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                // End marker
                if let end = viewModel.coordinates.last {
                    Annotation("도착", coordinate: end) {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 30, height: 30)
                            
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 30, height: 30)
                            
                            Text("E")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                // Photo markers
                ForEach(Array(viewModel.photoAnnotations.enumerated()), id: \.offset) { index, annotation in
                    Annotation("", coordinate: annotation.coordinate) {
                        Button {
                            viewModel.selectedPhotoIndex = index
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.blue.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            
            // Back button
            VStack {
                HStack {
                    Button {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $viewModel.showingBottomSheet) {
            RouteBottomSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(20)
                .presentationBackground(.ultraThinMaterial)
        }
        .onAppear {
            viewModel.showingBottomSheet = true
        }
    }
}

@MainActor
class RouteMapViewModel: ObservableObject {
    let route: Route
    @Published var cameraPosition: MapCameraPosition
    @Published var coordinates: [CLLocationCoordinate2D] = []
    @Published var photoAnnotations: [PhotoAnnotation] = []
    @Published var selectedPhotoIndex: Int?
    @Published var showingBottomSheet = false
    
    init(route: Route) {
        self.route = route
        
        // 기본 카메라 위치 (서울) - 먼저 초기화
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        self.cameraPosition = .region(defaultRegion)
        
        // 저장된 좌표 로드
        if let coordinatesData = route.coordinatesData,
           let storedCoordinates = try? JSONDecoder().decode([StoredCoordinate].self, from: coordinatesData) {
            self.coordinates = storedCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            
            // 사진 마커 생성
            for record in route.photoRecords {
                if let lat = record.latitude, let lon = record.longitude {
                    photoAnnotations.append(PhotoAnnotation(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        roadName: record.roadName,
                        timestamp: record.capturedAt
                    ))
                }
            }
            
            // 좌표가 있으면 카메라 위치 업데이트
            if !coordinates.isEmpty {
                let region = calculateRegion()
                self.cameraPosition = .region(region)
            }
        }
    }
    
    private func calculateRegion() -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        // 모든 좌표를 포함하는 영역 계산
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = (maxLat - minLat) * 1.5 // 여유 공간 추가
        let spanLon = (maxLon - minLon) * 1.5
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(spanLat, 0.01),
                longitudeDelta: max(spanLon, 0.01)
            )
        )
    }
    
    func shareRoute() {
        // TODO: 공유 기능 구현
    }
    
    func saveRoute() {
        // 이미 저장되어 있음
    }
}

struct PhotoAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let roadName: String?
    let timestamp: Date
}
