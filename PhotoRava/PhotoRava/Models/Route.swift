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
    var aiSummaryCaption: String?
    var aiSummaryDiary: String?
    var aiSummaryHighlights: [String] = []
    var aiSummaryToneRawValue: String?
    var aiSummaryConfidence: Double?
    var aiSummaryGeneratedAt: Date?
    var userEditedTitle: String?
    var userEditedCaption: String?
    var userEditedDiaryEntry: String?
    var userEditedHighlights: [String] = []
    
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

extension Route {
    @available(iOS 26.0, *)
    func apply(summary: RouteSummary) {
        name = summary.title
        aiSummaryCaption = summary.caption
        aiSummaryDiary = summary.diaryEntry
        aiSummaryHighlights = summary.highlights
        aiSummaryToneRawValue = summary.tone.rawValue
        aiSummaryConfidence = summary.confidence
        aiSummaryGeneratedAt = Date()
        clearUserEditedSummary()
    }

    func applyStoredSummary(
        title: String? = nil,
        caption: String?,
        diary: String?,
        highlights: [String],
        toneRawValue: String?,
        confidence: Double?
    ) {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = title
        }
        aiSummaryCaption = caption
        aiSummaryDiary = diary
        aiSummaryHighlights = highlights
        aiSummaryToneRawValue = toneRawValue
        aiSummaryConfidence = confidence
        aiSummaryGeneratedAt = Date()
        clearUserEditedSummary()
    }

    func clearUserEditedSummary() {
        userEditedTitle = nil
        userEditedCaption = nil
        userEditedDiaryEntry = nil
        userEditedHighlights = []
    }
}

struct RouteStoredSummary {
    var title: String?
    var caption: String?
    var diary: String?
    var highlights: [String]
    var toneRawValue: String?
    var confidence: Double?
}

extension RouteStoredSummary {
    static func fallback(
        for snapshot: RouteStatsSnapshot,
        tonePreference: RouteSummaryTonePreference
    ) -> RouteStoredSummary {
        let distanceText = String(format: "%.1f", snapshot.distanceKm)
        let timeLabel = snapshot.timeOfDay ?? "주간"
        let photoText = "\(snapshot.photoCount)장의 사진"
        let topPlace = shortLabel(from: snapshot.visitedRoadsTopN.first ?? snapshot.areaKeywords.first ?? snapshot.startName)
        let titleCandidate = normalizedText(snapshot.userEditedTitle ?? "").isEmpty
            ? "\(topPlace) \(timeLabel) 기록"
            : normalizedText(snapshot.userEditedTitle ?? "")
        let caption = "약 \(distanceText)km를 \(snapshot.durationMin)분 동안 이동하며 \(photoText)을 남긴 여정."

        let narrativeFocus = snapshot.visitedRoadsTopN.prefix(2).joined(separator: ", ")
        let focusSentence = narrativeFocus.isEmpty
            ? "사진의 시간 순서를 따라 이동 흐름이 자연스럽게 이어집니다."
            : "\(narrativeFocus) 주변의 흐름이 특히 또렷하게 남았습니다."

        let diary: String
        switch tonePreference {
        case .documentary:
            diary = """
            \(timeLabel)에 \(snapshot.startName)에서 출발해 \(snapshot.endName)까지 이어진 이동 기록입니다. \
            총 \(distanceText)km를 \(snapshot.durationMin)분 동안 이동했고, \(photoText)이 경로의 주요 장면을 남겼습니다. \
            \(focusSentence)
            """
        case .warm:
            diary = """
            \(timeLabel)에 \(snapshot.startName)에서 시작한 여정은 \(snapshot.endName)까지 차분히 이어졌습니다. \
            총 \(distanceText)km를 \(snapshot.durationMin)분 동안 움직이며 \(photoText) 속에 그날의 분위기를 담았습니다. \
            \(focusSentence)
            """
        }

        let highlights = deduplicatedHighlights([
            shortLabel(from: timeLabel),
            shortLabel(from: topPlace),
            shortLabel(from: "\(snapshot.durationMin)분 기록")
        ])

        return RouteStoredSummary(
            title: clampedTitle(titleCandidate, fallback: "\(timeLabel) 경로 기록"),
            caption: caption,
            diary: normalizedText(diary),
            highlights: highlights,
            toneRawValue: tonePreference.rawValue,
            confidence: 0.62
        )
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shortLabel(from value: String) -> String {
        let cleaned = normalizedText(value)
        return cleaned.isEmpty ? "경로 기록" : String(cleaned.prefix(20))
    }

    private static func clampedTitle(_ value: String, fallback: String) -> String {
        let cleaned = normalizedText(value)
        let candidate = cleaned.isEmpty ? fallback : cleaned
        return String(candidate.prefix(24))
    }

    private static func deduplicatedHighlights(_ values: [String]) -> [String] {
        var result: [String] = []
        for value in values {
            let label = shortLabel(from: value)
            if !result.contains(label) {
                result.append(label)
            }
        }
        if result.count < 2 {
            result.append("요약 생성 완료")
        }
        return Array(result.prefix(3))
    }
}

// MARK: - AI Summary Types

enum RouteSummaryTonePreference: String, CaseIterable, Identifiable {
    case warm
    case documentary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warm:
            return "따뜻한 감성"
        case .documentary:
            return "다큐멘터리"
        }
    }

    var promptGuide: String {
        switch self {
        case .warm:
            return "따뜻한 감성: 개인적인 여운, 부드러운 감정, 여행 일기처럼 자연스러운 표현을 사용하세요."
        case .documentary:
            return "다큐멘터리 스타일: 관찰자 시선, 사실 기반 묘사, 차분하고 기록적인 표현을 사용하세요."
        }
    }
}

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
    var userEditedCaption: String?  // 사용자가 이전에 편집한 캡션 (재생성 시 참고)
    var userEditedDiaryEntry: String? // 사용자가 이전에 편집한 일기 (재생성 시 참고)
    var userEditedHighlights: [String] // 사용자가 이전에 편집한 하이라이트 (재생성 시 참고)
}
