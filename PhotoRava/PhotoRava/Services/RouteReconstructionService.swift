//
//  RouteReconstructionService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import CoreLocation
import MapKit

class RouteReconstructionService {
    static let shared = RouteReconstructionService()
    private init() {}
    
    /// 기존 Route의 파생 데이터를 재계산하여 업데이트
    func recalculateRouteData(for route: Route) async {
        // 시간순 정렬 (SwiftData @Relationship 배열은 직접 수정)
        let sortedRecords = route.photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 배열 순서를 직접 수정 (SwiftData 호환)
        route.photoRecords.removeAll()
        route.photoRecords.append(contentsOf: sortedRecords)
        
        // 좌표 수집
        var coordinates: [StoredCoordinate] = []
        var geocodingFailures: [String] = []
        
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
                        
                        // 역지오코딩한 좌표를 레코드에 저장
                        record.latitude = geocoded.latitude
                        record.longitude = geocoded.longitude
                    } else {
                        geocodingFailures.append(roadName)
                    }
                } catch {
                    geocodingFailures.append(roadName)
                    print("Geocoding failed for \(roadName): \(error.localizedDescription)")
                }
            }
        }
        
        // 지오코딩 실패한 도로명이 있으면 로그 출력 (크래시 방지)
        if !geocodingFailures.isEmpty {
            print("Warning: Failed to geocode \(geocodingFailures.count) road names: \(geocodingFailures.joined(separator: ", "))")
        }
        
        // 좌표 데이터 저장
        do {
            if let coordinatesData = try? JSONEncoder().encode(coordinates) {
                route.coordinatesData = coordinatesData
            }
        } catch {
            print("Error encoding coordinates: \(error.localizedDescription)")
            // 좌표 인코딩 실패해도 계속 진행
        }
        
        // 통계 계산
        route.totalDistance = calculateDistance(coordinates)
        route.duration = calculateDuration(from: sortedRecords)
        
        // 중복 제거한 도로명 리스트 (좌표 유무와 무관하게 저장)
        route.roadNames = Array(
            Set(sortedRecords.compactMap { record in
                guard let name = record.roadName, !name.isEmpty else { return nil }
                return name
            })
        ).sorted()
    }
    
    func reconstructRoute(from photoRecords: [PhotoRecord]) async throws -> Route {
        guard !photoRecords.isEmpty else {
            throw RouteError.noPhotos
        }
        
        // 1. 시간순 정렬 (이미 정렬되어 있어야 함)
        let sortedRecords = photoRecords.sorted { $0.capturedAt < $1.capturedAt }
        
        // 2. 좌표 수집 (GPS-first, 필요 시 roadName 지오코딩 보완)
        var coordinates: [StoredCoordinate] = []
        var geocodingFailures: [String] = []
        
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
                    } else {
                        geocodingFailures.append(roadName)
                    }
                } catch {
                    geocodingFailures.append(roadName)
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
        
        // 좌표 데이터 저장
        if let coordinatesData = try? JSONEncoder().encode(coordinates) {
            route.coordinatesData = coordinatesData
        }
        
        // 통계 계산
        route.totalDistance = calculateDistance(coordinates)
        route.duration = calculateDuration(from: sortedRecords)
        
        // 중복 제거한 도로명 리스트 (좌표 유무와 무관하게 저장)
        route.roadNames = Array(
            Set(sortedRecords.compactMap { record in
                guard let name = record.roadName, !name.isEmpty else { return nil }
                return name
            })
        ).sorted()
        
        if !geocodingFailures.isEmpty {
            print("Warning: Failed to geocode \(geocodingFailures.count) road names: \(geocodingFailures.joined(separator: ", "))")
        }
        
        return route
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
