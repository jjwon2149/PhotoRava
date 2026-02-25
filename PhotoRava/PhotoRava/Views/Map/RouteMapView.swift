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
    
    init(route: Route, initialSelectedPhotoIndex: Int? = nil, onBack: (() -> Void)? = nil) {
        self.route = route
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: RouteMapViewModel(route: route, initialSelectedPhotoIndex: initialSelectedPhotoIndex))
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
                            withAnimation(.easeInOut) {
                                viewModel.selectPhoto(at: index)
                            }
                        } label: {
                            RoutePhotoMarkerView(
                                thumbnail: viewModel.photoThumbnails[annotation.id],
                                isSelected: viewModel.selectedPhotoIndex == index,
                                borderColor: viewModel.markerBorderColor(for: annotation.id)
                            )
                        }
                        .task(id: annotation.id) {
                            await viewModel.ensureThumbnail(for: annotation)
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
            // 초기 선택된 인덱스가 있으면 해당 위치로 이동
            if let index = viewModel.selectedPhotoIndex {
                viewModel.selectPhoto(at: index)
            }
        }
    }
}

@MainActor
class RouteMapViewModel: ObservableObject {
    let route: Route
    @Published var cameraPosition: MapCameraPosition
    @Published var coordinates: [CLLocationCoordinate2D] = []
    @Published var photoAnnotations: [PhotoAnnotation] = []
    @Published var photoThumbnails: [UUID: UIImage] = [:]
    @Published var selectedPhotoIndex: Int?
    @Published var showingBottomSheet = false
    
    private(set) var startPhotoId: UUID?
    private(set) var endPhotoId: UUID?
    
    private var inFlightThumbnailIds: Set<UUID> = []
    
    init(route: Route, initialSelectedPhotoIndex: Int? = nil) {
        self.route = route
        self.selectedPhotoIndex = initialSelectedPhotoIndex
        
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
                        id: record.id,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        roadName: record.roadName,
                        timestamp: record.capturedAt,
                        imageData: record.imageData
                    ))
                }
            }
            
            let sortedByTime = photoAnnotations.sorted(by: { $0.timestamp < $1.timestamp })
            startPhotoId = sortedByTime.first?.id
            endPhotoId = sortedByTime.last?.id
            
            // 좌표가 있으면 카메라 위치 업데이트
            if !coordinates.isEmpty {
                let region = calculateRegion()
                self.cameraPosition = .region(region)
            }
        }
    }
    
    func selectPhoto(at index: Int) {
        guard index >= 0 && index < photoAnnotations.count else { return }
        selectedPhotoIndex = index
        let coordinate = photoAnnotations[index].coordinate
        
        // 해당 사진 위치로 카메라 이동
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
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

    func ensureThumbnail(for annotation: PhotoAnnotation) async {
        if photoThumbnails[annotation.id] != nil { return }
        if inFlightThumbnailIds.contains(annotation.id) { return }
        guard let data = annotation.imageData else { return }
        
        inFlightThumbnailIds.insert(annotation.id)
        
        let targetSize = CGSize(width: 44, height: 44)
        Task.detached(priority: .utility) {
            let image: UIImage? = autoreleasepool {
                guard let base = UIImage(data: data) else { return nil }
                return base.routeMarkerThumbnail(targetSize: targetSize)
            }
            
            await MainActor.run {
                self.inFlightThumbnailIds.remove(annotation.id)
                if let image {
                    self.photoThumbnails[annotation.id] = image
                }
            }
        }
    }
    
    func markerBorderColor(for photoId: UUID) -> Color {
        if photoId == startPhotoId { return .green }
        if photoId == endPhotoId { return .red }
        return .white
    }
}

struct PhotoAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let roadName: String?
    let timestamp: Date
    let imageData: Data?
}

private struct RoutePhotoMarkerView: View {
    let thumbnail: UIImage?
    let isSelected: Bool
    let borderColor: Color
    
    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.yellow : borderColor, lineWidth: isSelected ? 3 : 2)
        }
        .shadow(radius: 2)
    }
}

private extension UIImage {
    func routeMarkerThumbnail(targetSize: CGSize) -> UIImage {
        let size = self.size
        guard size.width > 0, size.height > 0 else { return self }
        
        let scaleFactor = max(targetSize.width / size.width, targetSize.height / size.height)
        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2.0,
            y: (targetSize.height - scaledSize.height) / 2.0
        )
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
