//
//  RouteReconstructionService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import CoreLocation
import MapKit
import SwiftData

class RouteReconstructionService {
    static let shared = RouteReconstructionService()
    private init() {}
    
    /// 기존 Route의 파생 데이터를 재계산하여 업데이트
    func recalculateRouteData(for route: Route, modelContext: ModelContext? = nil) async {
        // 시간순 정렬 (SwiftData @Relationship 배열은 직접 수정)
        let sortedRecords = route.photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 배열 순서를 직접 수정 (SwiftData 호환)
        route.photoRecords.removeAll()
        route.photoRecords.append(contentsOf: sortedRecords)
        
        for (index, record) in sortedRecords.enumerated() {
            if shouldAttemptAIAnalysis(for: record) {
                if #available(iOS 26.0, *) {
                    Task {
                        await processAIAnalysis(
                            for: record,
                            index: index,
                            in: sortedRecords,
                            updateRoute: route,
                            modelContext: modelContext
                        )
                    }
                }
            }
        }
        
        // 초기 좌표 수집 (이미 있는 GPS 기반으로 먼저 경로 그리기)
        updateRouteStatistics(route, sortedRecords: sortedRecords)
        await persistChanges(in: modelContext)
    }

    @available(iOS 26.0, *)
    private func processAIAnalysis(
        for record: PhotoRecord,
        index: Int,
        in records: [PhotoRecord],
        updateRoute: Route?,
        modelContext: ModelContext?
    ) async {
        let aiService = LocalAIService.shared
        
        // 1. 컨텍스트 구성
        let input = buildAIContextInput(for: record, index: index, in: records)
        
        do {
            // 2. AI 쿼리 계획 생성
            let plan = try await aiService.routeGeocodePlanner(input: input)
            
            // 3. PhotoRecord 업데이트 (UI 반영용)
            record.aiQuery = plan.query
            record.aiConfidence = plan.confidence
            record.aiReason = plan.reason
            record.aiAlternatives = plan.alternatives
            
            // 4. 지오코딩 시도 (AI Query 우선 - 신뢰도 0.75 이상 시 자동 확정)
            if plan.confidence >= 0.75 {
                if let geocoded = try await geocodeWithAIPlan(plan) {
                    record.latitude = geocoded.latitude
                    record.longitude = geocoded.longitude
                    
                    // 5. Route 통계 재계산 트리거 (UI 알림용)
                    if let route = updateRoute {
                        await MainActor.run {
                            updateRouteStatistics(route, sortedRecords: records)
                        }
                    }
                }
            }
            await persistChanges(in: modelContext)
        } catch {
            print("AI Analysis failed for record \(record.id): \(error.localizedDescription)")
        }
    }

    @available(iOS 26.0, *)
    private func geocodeWithAIPlan(_ plan: GeocodeQueryPlan) async throws -> StoredCoordinate? {
        // 1순위: AI 정규화 쿼리
        if let result = try await geocodeUsingAppleMaps(roadName: plan.query) {
            return result
        }
        
        // 2순위: 대안 쿼리들
        for alt in plan.alternatives {
            if let result = try await geocodeUsingAppleMaps(roadName: alt) {
                return result
            }
        }
        
        return nil
    }

    private func updateRouteStatistics(_ route: Route, sortedRecords: [PhotoRecord]) {
        var coordinates: [StoredCoordinate] = []
        for record in sortedRecords {
            if let lat = record.latitude, let lon = record.longitude {
                coordinates.append(StoredCoordinate(latitude: lat, longitude: lon))
            }
        }
        
        // --- Feature 3: Path Optimization (Anomaly Detection) ---
        let optimizedCoordinates = optimizePath(coordinates)
        
        // 좌표 데이터 저장 (최적화된 좌표 사용)
        if let coordinatesData = try? JSONEncoder().encode(optimizedCoordinates) {
            route.coordinatesData = coordinatesData
        }
        
        route.totalDistance = calculateDistance(optimizedCoordinates)
        route.duration = calculateDuration(from: sortedRecords)
        route.roadNames = deduplicatedRoadNames(from: sortedRecords)
    }

    /// GPS 튐 현상이나 잘못된 OCR 좌표를 감지하여 경로를 매끄럽게 보정
    private func optimizePath(_ coordinates: [StoredCoordinate]) -> [StoredCoordinate] {
        guard coordinates.count > 2 else { return coordinates }
        
        var results = coordinates
        
        for i in 1..<(results.count - 1) {
            let prev = results[i-1]
            let current = results[i]
            let next = results[i+1]
            
            let distPrev = calculateDistanceBetween(prev, current) // km
            // 시간 데이터가 있다면 더 정확하겠지만, 여기서는 거리 기반 급격한 꺾임 감지 (Heuristic)
            
            // 단순 알고리즘: 이전/이후 지점과의 거리가 급격히 멀고, 
            // 이전-이후 지점은 가까운 경우 (V자 튐 현상)
            let distNext = calculateDistanceBetween(current, next)
            let distDirect = calculateDistanceBetween(prev, next)
            
            if distPrev + distNext > distDirect * 2.5 && distDirect < 5.0 {
                // 이상치 감지! (V자형 튐)
                results[i].isAnomaly = true
                results[i].isOptimized = true
                
                // 보정: 이전과 이후의 중간지점으로 이동
                results[i].latitude = (prev.latitude + next.latitude) / 2
                results[i].longitude = (prev.longitude + next.longitude) / 2
                print("AI Optimization: Corrected anomaly at index \(i)")
            }
        }
        
        return results
    }

    private func calculateDistanceBetween(_ p1: StoredCoordinate, _ p2: StoredCoordinate) -> Double {
        let loc1 = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let loc2 = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
        return loc1.distance(from: loc2) / 1000.0 // km
    }
    
    func reconstructRoute(from photoRecords: [PhotoRecord], modelContext: ModelContext? = nil) async throws -> Route {
        guard !photoRecords.isEmpty else {
            throw RouteError.noPhotos
        }
        
        // 1. 시간순 정렬 (이미 정렬되어 있어야 함)
        let sortedRecords = photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 2. 좌표 수집 (GPS-first, 필요 시 roadName 지오코딩 보완)
        var coordinates: [StoredCoordinate] = []
        
        for record in sortedRecords {
            // GPS 좌표가 있으면 사용
            if let lat = record.latitude, let lon = record.longitude {
                let coord = StoredCoordinate(latitude: lat, longitude: lon)
                coordinates.append(coord)
            }
            // GPS가 없으면 도로명으로 지오코딩 시도
            else if let roadName = record.roadName, !roadName.isEmpty {
                do {
                    if let geocoded = try await geocodeUsingAppleMaps(roadName: roadName) {
                        coordinates.append(geocoded)
                        
                        // 지오코딩한 좌표를 레코드에 저장
                        record.latitude = geocoded.latitude
                        record.longitude = geocoded.longitude
                    }
                } catch {
                    print("Geocoding failed for \(roadName): \(error.localizedDescription)")
                }
            }
        }
        
        guard !coordinates.isEmpty else {
            throw RouteError.noCoordinatesFound
        }
        
        // 3. 경로 생성
        let routeDate = sortedRecords.first?.capturedAt ?? Date()
        let routeName = generateRouteName(
            baseDate: routeDate,
            firstRoadName: sortedRecords.compactMap { $0.roadName }.first(where: { !$0.isEmpty })
        )
        
        let route = Route(
            name: routeName,
            date: routeDate
        )
        
        // 모든 PhotoRecord 추가 (도로명 없는 것도 포함)
        route.photoRecords = sortedRecords
        
        // AI 분석 비동기 시작 (기존 GPS 위주로 먼저 생성 후 보완)
        for (index, record) in sortedRecords.enumerated() {
            if shouldAttemptAIAnalysis(for: record) {
                if #available(iOS 26.0, *) {
                    Task {
                        await processAIAnalysis(
                            for: record,
                            index: index,
                            in: sortedRecords,
                            updateRoute: route,
                            modelContext: modelContext
                        )
                    }
                }
            }
        }

        // 초기 좌표 수집 및 통계 계산
        updateRouteStatistics(route, sortedRecords: sortedRecords)
        await persistChanges(in: modelContext)
        
        return route
    }

    private func shouldAttemptAIAnalysis(for record: PhotoRecord) -> Bool {
        guard record.latitude == nil || record.longitude == nil else { return false }

        if let roadName = normalized(record.roadName), !roadName.isEmpty {
            return true
        }
        if let rawOCRText = normalized(record.rawOCRText), !rawOCRText.isEmpty {
            return true
        }
        return !record.topOCRCandidates.isEmpty
    }

    private func buildAIContextInput(for record: PhotoRecord, index: Int, in records: [PhotoRecord]) -> OCRContextInput {
        let neighbors = extractNeighborHints(for: index, in: records)
        let baseCandidates = [record.roadName].compactMap { normalized($0) } + record.topOCRCandidates
        let normalizedCandidates = deduplicatedCandidates(from: baseCandidates)
        let rawText = normalized(record.rawOCRText) ?? normalized(record.roadName) ?? ""

        return OCRContextInput(
            rawText: rawText,
            topCandidates: normalizedCandidates,
            localeHint: Locale.current.identifier,
            neighborPhotoHints: neighbors
        )
    }
    
    // Apple Maps Geocoding (CLGeocoder)
    private func geocodeUsingAppleMaps(roadName: String) async throws -> StoredCoordinate? {
        let geocoder = CLGeocoder()
        
        // 한국 지역 힌트 추가
        let searchString = roadName.contains("서울") ? roadName : "\(roadName), 대한민국"
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(searchString)
            
            if let location = placemarks.first?.location {
                return StoredCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        } catch {
            print("Geocoding failed for \(roadName): \(error)")
        }
        
        return nil
    }

    /// 인근 사진들의 정보를 기반으로 AI 지오코딩을 위한 힌트들을 추출
    private func extractNeighborHints(for index: Int, in records: [PhotoRecord]) -> [NeighborHint] {
        var hints: [NeighborHint] = []
        
        // 이전 사진 힌트
        if index > 0 {
            let prev = records[index - 1]
            var coord: CLLocationCoordinate2D?
            if let lat = prev.latitude, let lon = prev.longitude {
                coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            hints.append(NeighborHint(direction: .previous, roadName: prev.roadName, coordinate: coord))
        }
        
        // 다음 사진 힌트
        if index < records.count - 1 {
            let next = records[index + 1]
            var coord: CLLocationCoordinate2D?
            if let lat = next.latitude, let lon = next.longitude {
                coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            hints.append(NeighborHint(direction: .next, roadName: next.roadName, coordinate: coord))
        }
        
        return hints
    }
    
    private func calculateDistance(_ coordinates: [StoredCoordinate]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 0..<(coordinates.count - 1) {
            let start = CLLocation(
                latitude: coordinates[i].latitude,
                longitude: coordinates[i].longitude
            )
            let end = CLLocation(
                latitude: coordinates[i + 1].latitude,
                longitude: coordinates[i + 1].longitude
            )
            
            totalDistance += start.distance(from: end)
        }
        
        // 미터를 킬로미터로 변환
        return totalDistance / 1000.0
    }
    
    private func calculateDuration(from records: [PhotoRecord]) -> TimeInterval {
        guard let first = records.first?.capturedAt, let last = records.last?.capturedAt else {
            return 0
        }
        return last.timeIntervalSince(first)
    }
    
    private func generateRouteName(baseDate: Date, firstRoadName: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일"
        formatter.locale = Locale(identifier: "ko_KR")
        
        let dateString = formatter.string(from: baseDate)
        
        // 첫 번째 도로명을 포함
        if let firstRoadName, !firstRoadName.isEmpty {
            return "\(dateString) \(firstRoadName)"
        }
        
        return "\(dateString) 경로"
    }

    /// AI 요약/제목 생성을 위한 경로 통계 스냅샷 빌드
    func buildStatsSnapshot(for route: Route) -> RouteStatsSnapshot {
        let sortedRecords = route.photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        let currentRoadNames = deduplicatedRoadNames(from: sortedRecords)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var dateRange = ""
        if let firstDate = sortedRecords.first?.capturedAt, let lastDate = sortedRecords.last?.capturedAt {
            let firstStr = formatter.string(from: firstDate)
            let lastStr = formatter.string(from: lastDate)
            dateRange = firstStr == lastStr ? firstStr : "\(firstStr) ~ \(lastStr)"
        }
        
        let startName = sortedRecords.first?.roadName ?? sortedRecords.first?.aiQuery ?? "알 수 없는 출발지"
        let endName = sortedRecords.last?.roadName ?? sortedRecords.last?.aiQuery ?? "알 수 없는 도착지"
        
        // 시간대 판별 (첫 사진 기준)
        var timeOfDay = "주간"
        if let firstTime = sortedRecords.first?.capturedAt {
            let hour = Calendar.current.component(.hour, from: firstTime)
            switch hour {
            case 6..<12: timeOfDay = "오전"
            case 12..<18: timeOfDay = "오후"
            case 18..<22: timeOfDay = "저녁"
            default: timeOfDay = "야간"
            }
        }
        
        return RouteStatsSnapshot(
            distanceKm: route.totalDistance,
            durationMin: Int(route.duration / 60),
            startName: startName,
            endName: endName,
            photoCount: route.photoCount,
            dateRange: dateRange,
            visitedRoadsTopN: Array(currentRoadNames.prefix(5)),
            timeOfDay: timeOfDay,
            areaKeywords: currentRoadNames,
            userEditedTitle: route.name
        )
    }

    private func deduplicatedRoadNames(from records: [PhotoRecord]) -> [String] {
        var seen: Set<String> = []
        return records.compactMap { normalized($0.roadName) ?? normalized($0.aiQuery) }
            .filter { roadName in
                let inserted = seen.insert(roadName).inserted
                return inserted
            }
            .sorted()
    }

    private func deduplicatedCandidates(from candidates: [String]) -> [String] {
        var seen: Set<String> = []
        return candidates.compactMap { candidate in
            let normalizedCandidate = normalized(candidate)
            guard let normalizedCandidate, !normalizedCandidate.isEmpty else { return nil }
            return seen.insert(normalizedCandidate).inserted ? normalizedCandidate : nil
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    @MainActor
    private func persistChanges(in modelContext: ModelContext?) {
        guard let modelContext else { return }
        try? modelContext.save()
    }
}

struct RoadPoint {
    let roadName: String
    let coordinate: StoredCoordinate
    let timestamp: Date
}

enum RouteError: LocalizedError {
    case noPhotos
    case noRoadNamesFound
    case noCoordinatesFound
    
    var errorDescription: String? {
        switch self {
        case .noPhotos:
            return "사진이 없습니다."
        case .noRoadNamesFound:
            return "도로명을 찾을 수 없습니다. 도로명 표지판이 포함된 사진을 선택해주세요."
        case .noCoordinatesFound:
            return "위치 정보를 찾을 수 없습니다."
        }
    }
}
