//
//  Route.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import SwiftData
import FoundationModels

@Model
class Route {
    var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var photoRecords: [PhotoRecord]
    var totalDistance: Double // km
    var duration: TimeInterval // seconds
    var roadNames: [String]
    
    // 지도용 좌표들 (JSON으로 저장)
    var coordinatesData: Data?
    
    var photoCount: Int {
        photoRecords.count
    }
    
    init(name: String, date: Date) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.photoRecords = []
        self.totalDistance = 0
        self.duration = 0
        self.roadNames = []
    }
}

// MARK: - AI Summary Types

@available(iOS 26.0, *)
@Generable
enum RouteTone: String {
    case neutral
    case warm
    case documentary
}

@available(iOS 26.0, *)
@Generable
struct RouteSummary {
    @Guide(description: "경로를 대표하는 제목. 10~24자 권장. 수치 포함 가능.")
    var title: String

    @Guide(description: "총 거리(km)와 소요 시간(분)을 반드시 포함한 한 줄 요약.")
    var caption: String
    
    @Guide(description: "여정을 감성적인 문장으로 풀어낸 한 편의 일기. 3~5문장 권장.")
    var diaryEntry: String

    @Guide(description: "경로의 핵심 포인트 2~3개. 중복 제거. 각 항목 20자 이내.")
    var highlights: [String]

    @Guide(description: "문체 톤. neutral / warm / documentary 중 하나.")
    var tone: RouteTone

    @Guide(description: "0.0(확신 없음)~1.0(확신) 범위의 신뢰도")
    var confidence: Double
}

struct RouteStatsSnapshot: Codable {
    var distanceKm: Double
    var durationMin: Int
    var startName: String
    var endName: String
    var photoCount: Int
    var dateRange: String           // "2026-03-04" 또는 "2026-03-04 ~ 2026-03-05"
    var visitedRoadsTopN: [String]  // 상위 N개 도로명
    var timeOfDay: String?          // "오전" / "오후" / "저녁" / "야간"
    var areaKeywords: [String]      // 지역 키워드 (구/동 수준)
    var userEditedTitle: String?    // 사용자가 이전에 편집한 제목 (재생성 시 참고)
}
