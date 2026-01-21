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
    @Query(sort: \Route.date, order: .reverse) private var routes: [Route]
    @State private var showingPhotoSelection = false
    @State private var searchText = ""
    
    // 검색 필터링된 경로
    var filteredRoutes: [Route] {
        guard !searchText.isEmpty else { return routes }
        
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        return routes.filter { route in
            // 경로 이름 검색
            route.name.lowercased().contains(searchLower) ||
            // 방문 도로명 검색
            route.roadNames.contains { $0.lowercased().contains(searchLower) } ||
            // 날짜 검색 (여러 포맷 지원)
            matchesDate(route.date, searchText: searchLower)
        }
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("내 경로")
            .searchable(text: $searchText, prompt: "경로 이름, 도로명, 날짜로 검색")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPhotoSelection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPhotoSelection) {
                PhotoSelectionView()
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
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 8) {
                Text("첫 경로를 만들어보세요")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("사진에서 위치 정보를 추출하여\n당신만의 특별한 여정을 자동으로 생성합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                showingPhotoSelection = true
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var routeListView: some View {
        List {
            ForEach(filteredRoutes) { route in
                NavigationLink {
                    TimelineDetailView(route: route)
                } label: {
                    RouteCardView(route: route)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(.plain)
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("검색 결과 없음")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("'\(searchText)'에 대한 결과를 찾을 수 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
        HStack(spacing: 16) {
            // Map Thumbnail
            RouteMapThumbnail(route: route)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Photo count badge
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("\(route.photoCount) PHOTOS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.primary)
                
                // Route name
                Text(route.name)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                // Date
                Text(route.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.systemBackground))
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
