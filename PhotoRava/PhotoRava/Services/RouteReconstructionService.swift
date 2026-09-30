//
//  RouteReconstructionService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
final class RouteReconstructionService {
    static let shared = RouteReconstructionService()
    private init() {}
    
    /// 기존 Route의 파생 데이터를 재계산하여 업데이트
    func recalculateRouteData(for route: Route) async throws {
        try Task.checkCancellation()

        // 시간순 정렬 (SwiftData @Relationship 배열은 직접 수정)
        let sortedRecords = route.photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 배열 순서를 직접 수정 (SwiftData 호환)
        route.photoRecords.removeAll()
        route.photoRecords.append(contentsOf: sortedRecords)
        
        var aiUpdates: [(PhotoRecord, AIAnalysisUpdate)] = []
        for (index, record) in sortedRecords.enumerated() {
            try Task.checkCancellation()
            if shouldAttemptAIAnalysis(for: record) {
                if #available(iOS 26.0, *) {
                    if let update = try await makeAIAnalysisUpdate(for: record, index: index, in: sortedRecords) {
                        aiUpdates.append((record, update))
                    }
                }
            }
        }

        try Task.checkCancellation()
        aiUpdates.forEach { apply($0.1, to: $0.0) }
        try updateRouteStatistics(route, sortedRecords: sortedRecords)
    }

    @available(iOS 26.0, *)
    private func makeAIAnalysisUpdate(
        for record: PhotoRecord,
        index: Int,
        in records: [PhotoRecord]
    ) async throws -> AIAnalysisUpdate? {
        let aiService = LocalAIService.shared
        let input = buildAIContextInput(for: record, index: index, in: records)

        do {
            try Task.checkCancellation()
            let plan = try await aiService.routeGeocodePlanner(input: input)
            try Task.checkCancellation()

            var coordinate: StoredCoordinate?
            if plan.confidence >= 0.75 {
                coordinate = try await geocodeWithAIPlan(plan)
            }
            try Task.checkCancellation()

            return AIAnalysisUpdate(
                query: plan.query,
                confidence: plan.confidence,
                reason: plan.reason,
                alternatives: plan.alternatives,
                coordinate: coordinate
            )
        } catch {
            if error is CancellationError || Task.isCancelled {
                throw CancellationError()
            }
            // AI 보완은 선택 사항이다. 기존 GPS/OCR 결과로 계속 진행한다.
            logNonSensitive(error, operation: "AI route location assistance")
            return nil
        }
    }

    private func apply(_ update: AIAnalysisUpdate, to record: PhotoRecord) {
        record.aiQuery = update.query
        record.aiConfidence = update.confidence
        record.aiReason = update.reason
        record.aiAlternatives = update.alternatives
        if let coordinate = update.coordinate {
            record.latitude = coordinate.latitude
            record.longitude = coordinate.longitude
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

    private func updateRouteStatistics(_ route: Route, sortedRecords: [PhotoRecord]) throws {
        let result = RouteGeometryCalculator.calculate(
            from: sortedRecords.map {
                RouteGeometryInput(
                    capturedAt: $0.capturedAt,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    roadName: $0.roadName,
                    fallbackRoadName: $0.aiQuery
                )
            }
        )

        route.coordinatesData = try JSONEncoder().encode(result.coordinates)
        route.totalDistance = result.distanceKilometers
        route.duration = result.duration
        route.roadNames = result.roadNames
    }
    
    func reconstructRoute(from photoRecords: [PhotoRecord]) async throws -> Route {
        guard !photoRecords.isEmpty else {
            throw RouteError.noPhotos
        }
        
        // 1. 시간순 정렬 (이미 정렬되어 있어야 함)
        let sortedRecords = photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 2. 좌표 수집 (GPS-first, 필요 시 roadName 지오코딩 보완)
        var coordinates: [StoredCoordinate] = []
        
        for record in sortedRecords {
            try Task.checkCancellation()
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
                    if error is CancellationError || Task.isCancelled {
                        throw CancellationError()
                    }
                    logNonSensitive(error, operation: "Route location lookup")
                }
            }
        }

        for (index, record) in sortedRecords.enumerated() {
            try Task.checkCancellation()
            if shouldAttemptAIAnalysis(for: record), #available(iOS 26.0, *) {
                if let update = try await makeAIAnalysisUpdate(for: record, index: index, in: sortedRecords) {
                    try Task.checkCancellation()
                    apply(update, to: record)
                }
            }
        }

        coordinates = sortedRecords.compactMap { record in
            guard let latitude = record.latitude, let longitude = record.longitude else { return nil }
            return StoredCoordinate(latitude: latitude, longitude: longitude)
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
        
        try Task.checkCancellation()
        try updateRouteStatistics(route, sortedRecords: sortedRecords)
        
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
        
        let placemarks = try await geocoder.geocodeAddressString(searchString)
        try Task.checkCancellation()

        if let location = placemarks.first?.location {
            return StoredCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
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
            userEditedTitle: route.userEditedTitle,
            userEditedCaption: route.userEditedCaption,
            userEditedDiaryEntry: route.userEditedDiaryEntry,
            userEditedHighlights: route.userEditedHighlights
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

    private func logNonSensitive(_ error: Error, operation: String) {
        let nsError = error as NSError
        print("\(operation) failed [\(nsError.domain):\(nsError.code)]")
    }

}

private struct AIAnalysisUpdate {
    let query: String
    let confidence: Double
    let reason: String
    let alternatives: [String]
    let coordinate: StoredCoordinate?
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
