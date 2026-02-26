//
//  TimelineDetailView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import MapKit

struct TimelineDetailView: View {
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingMapView = false
    @StateObject private var locationResolver = TimelineLocationResolver()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Map preview header
                mapPreviewSection
                
                // Timeline content
                VStack(alignment: .leading, spacing: 20) {
                    Text("Timeline")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 24)
                    
                    timelineList
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .offset(y: -20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingMapView = true
                } label: {
                    Image(systemName: "map")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            RouteEditView(route: route)
        }
        .fullScreenCover(isPresented: $showingMapView) {
            NavigationStack {
                RouteMapView(route: route)
            }
        }
    }
    
    private var mapPreviewSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Map
            if let coordinatesData = route.coordinatesData,
               let coordinates = try? JSONDecoder().decode([StoredCoordinate].self, from: coordinatesData) {
                
                let mapCoordinates = coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                
                Map(initialPosition: .region(calculateRegion(for: mapCoordinates))) {
                    MapPolyline(coordinates: mapCoordinates)
                        .stroke(.blue, lineWidth: 3)
                    
                    if let start = mapCoordinates.first {
                        Annotation("", coordinate: start) {
                            Circle().fill(.green).frame(width: 15, height: 15)
                        }
                    }
                    
                    if let end = mapCoordinates.last {
                        Annotation("", coordinate: end) {
                            Circle().fill(.red).frame(width: 15, height: 15)
                        }
                    }
                }
                .frame(height: 300)
                .allowsHitTesting(false)
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 300)
            }
            
            // Stats overlay
            HStack(spacing: 16) {
                StatOverlay(
                    title: "TOTAL DISTANCE",
                    value: String(format: "%.1f km", route.totalDistance)
                )
                
                StatOverlay(
                    title: "DURATION",
                    value: formatDuration(route.duration)
                )
            }
            .padding()
        }
    }
    
    private var timelineList: some View {
        VStack(spacing: 0) {
            ForEach(Array(route.photoRecords.enumerated()), id: \.element.id) { index, record in
                TimelineItemView(
                    record: record,
                    locationResolver: locationResolver,
                    isFirst: index == 0,
                    isLast: index == route.photoRecords.count - 1
                )
            }
        }
    }
    
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
            )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"
    }
}

struct StatOverlay: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TimelineItemView: View {
    let record: PhotoRecord
    @ObservedObject var locationResolver: TimelineLocationResolver
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Top line
                if !isFirst {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 24)
                }
                
                // Dot/Icon
                ZStack {
                    Circle()
                        .fill(dotColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                    
                    if isLast {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(dotColor)
                    } else {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Bottom line
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(minHeight: 60)
                }
            }
            
            // Content card
            HStack(spacing: 12) {
                // Photo thumbnail
                if let imageData = record.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(addressTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Confidence indicator
                    if record.ocrConfidence > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: record.ocrConfidence > 0.8 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text(String(format: "%.0f%% 일치", record.ocrConfidence * 100))
                                .font(.caption2)
                        }
                        .foregroundStyle(record.ocrConfidence > 0.8 ? .green : .orange)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .task {
            // 좌표가 있다면 주소(동/구/시) 변환을 항상 시도합니다.
            if let lat = record.latitude, let lon = record.longitude {
                await locationResolver.resolveIfNeeded(latitude: lat, longitude: lon)
            }
        }
    }
    
    private var addressTitle: String {
        // 1순위: GPS 기반 행정 주소
        if let lat = record.latitude, let lon = record.longitude {
            if let cached = locationResolver.cachedName(latitude: lat, longitude: lon) {
                return cached
            }
            // 아직 변환 전이라면 좌표를 보여줍니다.
            return locationResolver.fallbackCoordinateText(latitude: lat, longitude: lon)
        }
        // 2순위: GPS가 없고 도로명만 있는 경우 (OCR 결과물)
        if let roadName = record.roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !roadName.isEmpty {
            return roadName
        }
        return "위치 알 수 없음"
    }

    private var subtitleText: String {
        let time = record.capturedAt.formatted(date: .omitted, time: .shortened)
        
        // 인식된 도로명이 있고, 그것이 제목과 중복되지 않을 때만 부제목에 추가
        if let roadName = record.roadName?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !roadName.isEmpty, 
           roadName != addressTitle {
            return "\(time) · \(roadName)"
        }
        
        return time
    }
    
    private var dotColor: Color {
        if isFirst {
            return .primaryBlue
        } else if isLast {
            return .primaryBlue
        } else {
            return Color(.systemGray)
        }
    }
}
