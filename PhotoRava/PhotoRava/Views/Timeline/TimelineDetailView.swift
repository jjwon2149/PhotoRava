//
//  TimelineDetailView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct TimelineDetailView: View {
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingMapView = false
    @State private var selectedPhotoForReview: PhotoRecord?
    @State private var showingRecommendationSheet = false
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
        .sheet(isPresented: $showingRecommendationSheet) {
            if let photo = selectedPhotoForReview {
                GeocodeRecommendationSheet(photo: photo, route: route)
                    .presentationDetents([PresentationDetent.medium])
            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("\(String(format: "%.1f", route.totalDistance)) km · \(Int(route.duration / 60)) min")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
    
    private var timelineList: some View {
        let sortedRecords = route.photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        return VStack(spacing: 0) {
            ForEach(Array(sortedRecords.enumerated()), id: \.offset) { index, record in
                TimelineItemView(
                    record: record,
                    locationResolver: locationResolver,
                    isFirst: index == 0,
                    isLast: index == sortedRecords.count - 1
                ) {
                    // 신뢰도가 낮거나 좌표가 없는 경우 시트 오픈
                    if let conf = record.aiConfidence, conf < 0.75 {
                        selectedPhotoForReview = record
                        showingRecommendationSheet = true
                    } else if record.latitude == nil && record.aiQuery != nil {
                        selectedPhotoForReview = record
                        showingRecommendationSheet = true
                    }
                }
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
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

struct TimelineItemView: View {
    let record: PhotoRecord
    @ObservedObject var locationResolver: TimelineLocationResolver
    let isFirst: Bool
    let isLast: Bool
    var onReviewTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line and dot column
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
            .frame(width: 44)
            
            // Content card
            Button {
                onReviewTap?()
            } label: {
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
                            .multilineTextAlignment(.leading)
                        
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // AI/OCR Status indicators
                        HStack(spacing: 8) {
                            // AI Confidence Indicator (Capsule Badge)
                            if let aiConf = record.aiConfidence {
                                HStack(spacing: 4) {
                                    Image(systemName: aiConf >= 0.75 ? "sparkles" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(String(format: aiConf >= 0.75 ? "AI %.0f%%" : "확인 필요 %.0f%%", aiConf * 100))
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(aiConf >= 0.75 ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                                )
                                .foregroundStyle(aiConf >= 0.75 ? .blue : .orange)
                            } else if record.latitude == nil && record.longitude == nil {
                                // Still analyzing or pending
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .scaleEffect(0.7)
                                    Text("AI 분석 중")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(.systemGray6)))
                                .foregroundStyle(.secondary)
                            }
                            
                            // Legacy OCR Confidence
                            if record.ocrConfidence > 0 && record.aiConfidence == nil {
                                HStack(spacing: 4) {
                                    Image(systemName: record.ocrConfidence > 0.8 ? "checkmark" : "exclamationmark")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(String(format: "OCR %.0f%%", record.ocrConfidence * 100))
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(record.ocrConfidence > 0.8 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                )
                                .foregroundStyle(record.ocrConfidence > 0.8 ? .green : .orange)
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .task {
            if let lat = record.latitude, let lon = record.longitude {
                await locationResolver.resolveIfNeeded(latitude: lat, longitude: lon)
            }
        }
    }
    
    private var addressTitle: String {
        if let lat = record.latitude, let lon = record.longitude {
            if let cached = locationResolver.cachedName(latitude: lat, longitude: lon) {
                return cached
            }
            return locationResolver.fallbackCoordinateText(latitude: lat, longitude: lon)
        }
        if let aiQuery = record.aiQuery, !aiQuery.isEmpty {
            return aiQuery
        }
        if let roadName = record.roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !roadName.isEmpty {
            return roadName
        }
        return "위치 알 수 없음"
    }

    private var subtitleText: String {
        let time = record.capturedAt.formatted(date: .omitted, time: .shortened)
        if let roadName = record.roadName?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !roadName.isEmpty, 
           roadName != addressTitle {
            return "\(time) · \(roadName)"
        }
        return time
    }
    
    private var dotColor: Color {
        if isFirst || isLast {
            return .primaryBlue
        } else {
            return Color(.systemGray)
        }
    }
}

// MARK: - GeocodeRecommendationSheet (Merged to ensure visibility)

struct GeocodeRecommendationSheet: View {
    let photo: PhotoRecord
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Text("AI가 분석한 위치 정보가 불분명합니다.")
                            .font(.headline)
                        
                        if let reason = photo.aiReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("추천 주소 선택") {
                    if let query = photo.aiQuery, !query.isEmpty {
                        suggestionRow(query, confidence: photo.aiConfidence ?? 0, isTop: true)
                    }
                    
                    ForEach(photo.aiAlternatives, id: \.self) { alt in
                        suggestionRow(alt, confidence: (photo.aiConfidence ?? 0) * 0.8, isTop: false)
                    }
                }
                
                Section {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("나중에 결정하기")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("위치 확인")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    ProgressView("위치 업데이트 중...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func suggestionRow(_ query: String, confidence: Double, isTop: Bool) -> some View {
        Button {
            Task { await selectQuery(query) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(query)
                        .font(.body)
                        .fontWeight(isTop ? .bold : .regular)
                        .foregroundStyle(.primary)
                    
                    Text(String(format: "신뢰도 %.0f%%", confidence * 100))
                        .font(.caption2)
                        .foregroundStyle(confidence >= 0.7 ? .blue : .secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @MainActor
    private func selectQuery(_ query: String) async {
        isProcessing = true
        defer { isProcessing = false }
        
        let geocoder = CLGeocoder()
        let searchString = query.contains("서울") ? query : "\(query), 대한민국"
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(searchString)
            if let location = placemarks.first?.location {
                // 좌표 업데이트
                photo.latitude = location.coordinate.latitude
                photo.longitude = location.coordinate.longitude
                photo.aiQuery = query
                photo.aiConfidence = 1.0 // 사용자 확정
                
                // Route 통계 재계산
                await RouteReconstructionService.shared.recalculateRouteData(for: route)
                
                // 저장
                try? modelContext.save()
                
                dismiss()
            }
        } catch {
            print("Geocoding failed for selected query: \(error)")
        }
    }
}
