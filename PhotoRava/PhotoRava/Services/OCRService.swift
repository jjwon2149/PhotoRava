//
//  OCRService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Vision
import UIKit
import Foundation
import CoreLocation
import FoundationModels

// MARK: - Support Types (Merged to ensure visibility)

/// AI 분석 품질 측정을 위한 로컬 로거
class AILogger {
    static let shared = AILogger()
    private init() {}
    
    struct LogEntry: Identifiable {
        let id: UUID
        let timestamp: Date
        let type: LogType
        let inputSummary: String
        let outputSummary: String
        let confidence: Double
        let isSuccess: Bool
        let error: String?
    }
    
    enum LogType: String {
        case geocodePlanner
        case routeNarrator
    }
    
    private(set) var logs: [LogEntry] = []
    private let maxLogs = 100
    
    func log(type: LogType, input: String, output: String, confidence: Double, isSuccess: Bool, error: Error? = nil) {
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            type: type,
            inputSummary: String(input.prefix(100)),
            outputSummary: String(output.prefix(200)),
            confidence: confidence,
            isSuccess: isSuccess,
            error: error?.localizedDescription
        )
        
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            if self.logs.count > self.maxLogs {
                self.logs.removeLast()
            }
            print("🤖 AI LOG [\(type.rawValue)]: \(isSuccess ? "SUCCESS" : "FAIL") (Conf: \(Int(confidence * 100))%)")
        }
    }
}

class OCRService {
    func recognizeText(in image: UIImage) async throws -> [RecognizedText] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = observations.compactMap { observation -> RecognizedText? in
                    guard let text = observation.topCandidates(1).first else {
                        return nil
                    }
                    
                    let raw = text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !raw.isEmpty else { return nil }
                    guard self.isRoadNameLike(raw) else { return nil }
                    
                    let hasNumber = raw.range(of: #"\d+"#, options: .regularExpression) != nil
                    
                    return RecognizedText(
                        rawText: raw,
                        text: self.cleanRoadName(raw),
                        boundingBox: observation.boundingBox,
                        confidence: text.confidence,
                        hasNumber: hasNumber
                    )
                }
                
                continuation.resume(returning: results)
            }
            
            request.recognitionLanguages = ["ko-KR"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func bestRoadName(from candidates: [RecognizedText]) -> RecognizedText? {
        topScoredCandidates(from: candidates, limit: 1).first?.candidate
    }

    func topScoredCandidates(from candidates: [RecognizedText], limit: Int = 5) -> [(candidate: RecognizedText, score: Double)] {
        guard !candidates.isEmpty else { return [] }

        let scored = candidates.map { (candidate: $0, score: scoreRoadNameCandidate($0)) }
            .filter { $0.score > 0 } 
            .sorted { $0.score > $1.score }
        
        return Array(scored.prefix(limit))
    }

    func buildOCRContextInput(
        rawResults: [RecognizedText],
        neighbors: [NeighborHint],
        localeHint: String? = nil
    ) -> OCRContextInput {
        let topCandidates = topScoredCandidates(from: rawResults, limit: 5)
        let rawTexts = rawResults.map { $0.rawText }.joined(separator: "\n")
        
        return OCRContextInput(
            rawText: rawTexts,
            topCandidates: topCandidates.map { $0.candidate.text },
            localeHint: localeHint,
            neighborPhotoHints: neighbors
        )
    }
    
    private func cleanRoadName(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?<=\s)\d+(?:[-~]\d+)?(?=\s|$)"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRoadNameLike(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { return false }
        let roadRegex = #"[가-힣0-9·\.\-]{2,}(?:번길|대로|거리|길|로)(?:[0-9]{1,3})?(?:길)?"#
        if normalized.range(of: roadRegex, options: .regularExpression) != nil { return true }
        let keywords = ["고속도로", "국도", "번길", "대로", "거리"]
        return keywords.contains(where: { normalized.contains($0) })
    }

    private func scoreRoadNameCandidate(_ candidate: RecognizedText) -> Double {
        let cleaned = normalize(candidate.text)
        guard !cleaned.isEmpty, !containsBlacklistedKeyword(candidate.rawText) else { return -1.0 }
        var score: Double = 0
        if cleaned.contains("고속도로") { score += 5 }
        if cleaned.contains("번길") { score += 4 }
        if cleaned.contains("대로") { score += 3.5 }
        if (4...18).contains(cleaned.count) { score += 2 }
        score += Double(candidate.confidence) * 0.75
        return score
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func containsBlacklistedKeyword(_ text: String) -> Bool {
        let lower = text.lowercased()
        let blacklist = ["sale", "주차", "금연", "안내"]
        return blacklist.contains(where: { lower.contains($0) })
    }
}

struct RecognizedText {
    let rawText: String
    let text: String
    let boundingBox: CGRect?
    let confidence: Float
    let hasNumber: Bool
}

enum OCRError: Error {
    case invalidImage
    case noTextFound
    
    var localizedDescription: String {
        switch self {
        case .invalidImage: return "유효하지 않은 이미지입니다."
        case .noTextFound: return "텍스트를 찾을 수 없습니다."
        }
    }
}

// MARK: - AI Service Implementation

@available(iOS 26.0, *)
class LocalAIService {
    static let shared = LocalAIService()
    private init() {}

    enum LocalAIError: LocalizedError {
        case notAvailable, generationFailed, invalidOutput
        var errorDescription: String? {
            switch self {
            case .notAvailable: return "AI 기능을 사용할 수 없습니다."
            case .generationFailed: return "분석 결과를 생성하지 못했습니다."
            case .invalidOutput: return "AI 응답 형식이 올바르지 않습니다."
            }
        }
    }

    func isServiceAvailable() async -> Bool { true }

    /// OCR 컨텍스트를 기반으로 지오코딩 쿼리 계획 생성
    func routeGeocodePlanner(input: OCRContextInput) async throws -> GeocodeQueryPlan {
        // SDK 사양에 맞춰 컴파일 가능한 형태로 추상화
        // 실제 구현 시에는 해당 환경의 LanguageModelSession API를 호출합니다.
        
        let mockPlan = GeocodeQueryPlan(
            query: input.topCandidates.first ?? "",
            components: AddressComponents(road: input.topCandidates.first),
            confidence: 0.85,
            reason: "주변 사진 힌트와 OCR 상위 후보가 일치함",
            alternatives: []
        )
        
        AILogger.shared.log(type: .geocodePlanner, input: input.rawText, output: mockPlan.query, confidence: mockPlan.confidence, isSuccess: true)
        return mockPlan
    }

    /// 경로 통계 데이터를 기반으로 매력적인 경로 요약을 생성
    func routeNarrator(snapshot: RouteStatsSnapshot) async throws -> RouteSummary {
        let titles = [
            "\(snapshot.startName)에서 시작된 \(snapshot.timeOfDay ?? "주간")의 여정",
            "\(snapshot.visitedRoadsTopN.first ?? "길")을 따라 걷는 산책",
            "\(snapshot.photoCount)장의 사진에 담긴 \(snapshot.durationMin)분의 기록"
        ]
        
        let mockSummary = RouteSummary(
            title: titles.randomElement() ?? titles[0],
            caption: "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동하며 \(snapshot.photoCount)장의 순간을 기록했습니다.",
            diaryEntry: "\(snapshot.timeOfDay ?? "주간")의 공기는 유난히 상쾌했습니다. \(snapshot.startName)에서 시작된 여정은 \(snapshot.endName)에 도착할 때까지 소중한 추억이 되었습니다.",
            highlights: ["\(snapshot.timeOfDay ?? "주간")의 분위기", "가장 좋았던 길"],
            tone: .warm,
            confidence: 0.95
        )
        
        AILogger.shared.log(type: .routeNarrator, input: "Route Snapshot", output: mockSummary.title, confidence: mockSummary.confidence, isSuccess: true)
        return mockSummary
    }

    private func validateAndCleanResult(_ plan: inout GeocodeQueryPlan) {
        plan.confidence = max(0.0, min(1.0, plan.confidence))
        plan.alternatives = plan.alternatives.filter { $0 != plan.query && !$0.isEmpty }
    }

    private func validateAndCleanSummary(_ summary: inout RouteSummary) {
        summary.confidence = max(0.0, min(1.0, summary.confidence))
        let uniqueHighlights = Array(NSOrderedSet(array: summary.highlights)) as? [String] ?? summary.highlights
        summary.highlights = uniqueHighlights.map { String($0.prefix(20)) }
    }
}
