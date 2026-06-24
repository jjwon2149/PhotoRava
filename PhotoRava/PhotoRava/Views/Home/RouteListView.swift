//
//  RouteListView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData
import MapKit

struct RouteListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var appState = AppState.shared
    @Query(sort: \Route.date, order: .reverse) private var routes: [Route]
    @State private var showingPhotoSelection = false
    @State private var searchText = ""
    @State private var isTransferringAnalysis = false

    private var totalPhotoCount: Int {
        routes.reduce(0) { $0 + $1.photoCount }
    }

    private var totalDistance: Double {
        routes.reduce(0) { $0 + $1.totalDistance }
    }
    
    // 검색 필터링된 경로
    var filteredRoutes: [Route] {
        guard !searchText.isEmpty else { return routes }
        
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        return routes.filter { route in
            // 경로 이름 검색
            route.name.lowercased().contains(searchLower) ||
            // AI 요약 검색
            (route.aiSummaryCaption?.lowercased().contains(searchLower) ?? false) ||
            (route.aiSummaryDiary?.lowercased().contains(searchLower) ?? false) ||
            route.aiSummaryHighlights.contains { $0.lowercased().contains(searchLower) } ||
            // 방문 도로명 검색
            route.roadNames.contains { $0.lowercased().contains(searchLower) } ||
            // 날짜 검색 (여러 포맷 지원)
            matchesDate(route.date, searchText: searchLower)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Group {
                    if filteredRoutes.isEmpty {
                        if searchText.isEmpty {
                            emptyStateView
                        } else {
                            searchEmptyStateView
                        }
                    } else {
                        routeListView
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RouteListAdBannerView()
                    .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("PhotoRava")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "경로 이름, 도로명, 날짜로 검색")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPhotoSelection = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("새 경로 만들기")
                }
            }
            .sheet(isPresented: $showingPhotoSelection) {
                PhotoSelectionView()
            }
            .fullScreenCover(isPresented: $isTransferringAnalysis, onDismiss: {
                appState.pendingPhotosForAnalysis = nil
            }) {
                if let photos = appState.pendingPhotosForAnalysis {
                    AnalysisProgressView(photos: photos)
                }
            }
            .onChange(of: appState.pendingPhotosForAnalysis) { _, newValue in
                if newValue != nil {
                    isTransferringAnalysis = true
                }
            }
            .onAppear {
                if appState.pendingPhotosForAnalysis != nil {
                    isTransferringAnalysis = true
                }
            }
        }
    }
    
    // 날짜 매칭 함수 (여러 포맷 지원)
    private func matchesDate(_ date: Date, searchText: String) -> Bool {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "ko_KR")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM월 dd일"
                f.locale = Locale(identifier: "ko_KR")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy년 MM월 dd일"
                f.locale = Locale(identifier: "ko_KR")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.locale = Locale(identifier: "ko_KR")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateStyle = .long
                f.locale = Locale(identifier: "ko_KR")
                return f
            }()
        ]
        
        for formatter in formatters {
            let dateString = formatter.string(from: date).lowercased()
            if dateString.contains(searchText) {
                return true
            }
        }
        
        return false
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primaryBlue.opacity(0.24),
                                    Color.green.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)

                    Image(systemName: "map.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }

                VStack(spacing: 10) {
                    Text("사진으로 여정을 복원하세요")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("GPS와 촬영 시간을 분석해 이동 경로를 만들고, AI 요약과 EXIF 스탬프까지 한 번에 정리합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                }
            }

            HStack(spacing: 8) {
                EmptyFeatureBadge(title: "경로 분석", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                EmptyFeatureBadge(title: "AI 기록", systemImage: "sparkles")
                EmptyFeatureBadge(title: "EXIF 스탬프", systemImage: "text.below.photo")
            }

            Button {
                showingPhotoSelection = true
            } label: {
                Label("사진 선택하기", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260, minHeight: 52)
                    .background(Color.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var routeListView: some View {
        List {
            if searchText.isEmpty {
                RouteOverviewHeader(
                    routeCount: routes.count,
                    photoCount: totalPhotoCount,
                    distance: totalDistance
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(filteredRoutes) { route in
                ZStack {
                    RouteCardView(route: route)
                    
                    NavigationLink {
                        TimelineDetailView(route: route)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 8) {
                Text("검색 결과 없음")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("'\(searchText)'에 대한 결과를 찾을 수 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRoutes[index])
        }
        try? modelContext.save()
    }
}

struct RouteCardView: View {
    let route: Route
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RouteMapThumbnail(route: route)
                .frame(width: 104, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 9) {
                Text(route.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)

                if let caption = route.aiSummaryCaption,
                   !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    RouteMetaPill(title: "\(route.photoCount)", systemImage: "photo")
                    RouteMetaPill(title: formattedDistance, systemImage: "arrow.triangle.turn.up.right.circle")

                    if route.duration > 0 {
                        RouteMetaPill(title: formattedDuration, systemImage: "clock")
                    }
                }

                if !route.aiSummaryHighlights.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(route.aiSummaryHighlights.prefix(2), id: \.self) { highlight in
                                Text(highlight)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primaryBlue.opacity(0.10))
                                    .foregroundStyle(Color.primaryBlue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Text(route.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    private var formattedDistance: String {
        guard route.totalDistance > 0 else { return "0km" }
        return String(format: "%.1fkm", route.totalDistance)
    }

    private var formattedDuration: String {
        let minutes = max(Int(route.duration / 60), 1)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

private struct RouteOverviewHeader: View {
    let routeCount: Int
    let photoCount: Int
    let distance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("사진 속 이동을 지도와 기록으로")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("저장된 여정을 빠르게 훑고, 새 사진으로 다음 경로를 분석하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                Spacer(minLength: 12)

                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primaryBlue)
                    .padding(10)
                    .background(Color.primaryBlue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                RouteStatTile(value: "\(routeCount)", label: "경로")
                RouteStatTile(value: "\(photoCount)", label: "사진")
                RouteStatTile(value: String(format: "%.1fkm", distance), label: "거리")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.primaryBlue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct RouteStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct RouteMetaPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

private struct EmptyFeatureBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
    }
}

// 지도 썸네일 (스냅샷)
struct RouteMapThumbnail: View {
    let route: Route
    @State private var snapshotImage: UIImage?
    
    var body: some View {
        Group {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                }
            }
        }
        .task {
            await generateSnapshot()
        }
    }
    
    private func generateSnapshot() async {
        guard let coordinatesData = route.coordinatesData,
              let coordinates = try? JSONDecoder().decode([StoredCoordinate].self, from: coordinatesData),
              !coordinates.isEmpty else {
            return
        }
        
        let mapCoordinates = coordinates.map { 
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
        }
        
        // 중심점 계산
        let avgLat = mapCoordinates.map { $0.latitude }.reduce(0, +) / Double(mapCoordinates.count)
        let avgLon = mapCoordinates.map { $0.longitude }.reduce(0, +) / Double(mapCoordinates.count)
        let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        
        // 스팬 계산 (모든 좌표를 포함하도록)
        let latitudes = mapCoordinates.map { $0.latitude }
        let longitudes = mapCoordinates.map { $0.longitude }
        let latDelta = (latitudes.max() ?? 0) - (latitudes.min() ?? 0)
        let lonDelta = (longitudes.max() ?? 0) - (longitudes.min() ?? 0)
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta * 1.5, 0.01),
            longitudeDelta: max(lonDelta * 1.5, 0.01)
        )
        
        let region = MKCoordinateRegion(center: center, span: span)
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 192, height: 192) // 2x for retina
        options.scale = UIScreen.main.scale
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            snapshotImage = snapshot.image
        } catch {
            print("Snapshot error: \(error)")
        }
    }
}


// Preview용 더미 데이터
extension Route {
    static var sampleData: [Route] {
        let route1 = Route(name: "서울 도심 산책", date: Date().addingTimeInterval(-86400 * 7))
        route1.totalDistance = 12.4
        route1.duration = 6300
        route1.roadNames = ["올림픽대로", "강남대로", "테헤란로"]
        
        let route2 = Route(name: "강릉 해변 드라이브", date: Date().addingTimeInterval(-86400 * 10))
        route2.totalDistance = 45.2
        route2.duration = 7200
        route2.roadNames = ["해안로", "강변로"]
        
        return [route1, route2]
    }
}
