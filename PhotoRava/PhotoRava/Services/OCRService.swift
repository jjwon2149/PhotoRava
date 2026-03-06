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
final class LocalAIService {
    static let shared = LocalAIService()

    private let geocodeModel = SystemLanguageModel(useCase: .contentTagging)
    private let routeSummaryModel = SystemLanguageModel(useCase: .general)

    private lazy var geocodeSession = LanguageModelSession(model: geocodeModel) {
        """
        당신은 한국 도로명 OCR 결과를 CLGeocoder용 질의로 정규화하는 도우미입니다.
        OCR 노이즈, 광고 문구, 슬로건은 제거하고 실제 주소 검색에 도움이 되는 정보만 남기세요.
        근거가 약한 행정구역은 억지로 추가하지 말고, 후보와 인접 사진 힌트에 기반해 보수적으로 응답하세요.
        """
    }

    private lazy var routeSummarySession = LanguageModelSession(model: routeSummaryModel) {
        """
        당신은 사진 기반 이동 경로를 한국어로 요약하는 기록 작성 도우미입니다.
        title은 짧고 기억에 남게, caption은 거리와 시간을 반드시 포함하게, diaryEntry는 3~5문장으로 자연스럽게 작성하세요.
        highlights는 짧고 겹치지 않게 2~3개만 제안하세요.
        """
    }

    private init() {}

    enum LocalAIError: LocalizedError {
        case notAvailable(SystemLanguageModel.Availability)
        case unsupportedLocale
        case invalidOutput

        var errorDescription: String? {
            switch self {
            case .notAvailable(let availability):
                switch availability {
                case .available:
                    return "AI 기능을 사용할 수 없습니다."
                case .unavailable(let reason):
                    switch reason {
                    case .deviceNotEligible:
                        return "이 기기는 Apple Intelligence를 지원하지 않습니다."
                    case .appleIntelligenceNotEnabled:
                        return "Apple Intelligence가 활성화되어 있지 않습니다."
                    case .modelNotReady:
                        return "온디바이스 모델 준비가 완료되지 않았습니다."
                    }
                }
            case .unsupportedLocale:
                return "현재 언어 설정에서는 AI 기능을 사용할 수 없습니다."
            case .invalidOutput: return "AI 응답 형식이 올바르지 않습니다."
            }
        }
    }

    func isServiceAvailable() async -> Bool {
        isModelReady(geocodeModel) || isModelReady(routeSummaryModel)
    }

    func prewarmIfNeeded() {
        guard isModelReady(geocodeModel) || isModelReady(routeSummaryModel) else { return }
        geocodeSession.prewarm(promptPrefix: Prompt("도로명 OCR을 정규화합니다."))
        routeSummarySession.prewarm(promptPrefix: Prompt("경로 통계를 간결한 여행 기록으로 요약합니다."))
    }

    /// OCR 컨텍스트를 기반으로 지오코딩 쿼리 계획 생성
    func routeGeocodePlanner(input: OCRContextInput) async throws -> GeocodeQueryPlan {
        let normalizedInput = normalize(input: input)
        let fallback = fallbackGeocodePlan(for: normalizedInput)

        guard hasLocationEvidence(in: normalizedInput) else {
            return fallback
        }

        do {
            guard isModelReady(geocodeModel) else {
                throw LocalAIError.notAvailable(geocodeModel.availability)
            }
            guard supportsPreferredLocale(geocodeModel) else {
                throw LocalAIError.unsupportedLocale
            }

            let response = try await geocodeSession.respond(
                to: geocodePrompt(for: normalizedInput),
                generating: GeocodeQueryPlan.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 220)
            )

            var plan = response.content
            validateAndCleanResult(&plan, fallback: fallback)
            guard !plan.query.isEmpty else {
                throw LocalAIError.invalidOutput
            }

            AILogger.shared.log(
                type: .geocodePlanner,
                input: geocodeLogInput(for: normalizedInput),
                output: plan.query,
                confidence: plan.confidence,
                isSuccess: true
            )
            return plan
        } catch {
            var plan = fallback
            validateAndCleanResult(&plan, fallback: fallback)
            AILogger.shared.log(
                type: .geocodePlanner,
                input: geocodeLogInput(for: normalizedInput),
                output: plan.query,
                confidence: plan.confidence,
                isSuccess: false,
                error: error
            )
            return plan
        }
    }

    /// 경로 통계 데이터를 기반으로 매력적인 경로 요약을 생성
    func routeNarrator(snapshot: RouteStatsSnapshot) async throws -> RouteSummary {
        let fallback = fallbackRouteSummary(for: snapshot)

        do {
            guard isModelReady(routeSummaryModel) else {
                throw LocalAIError.notAvailable(routeSummaryModel.availability)
            }
            guard supportsPreferredLocale(routeSummaryModel) else {
                throw LocalAIError.unsupportedLocale
            }

            let response = try await routeSummarySession.respond(
                to: routeSummaryPrompt(for: snapshot),
                generating: RouteSummary.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 420)
            )

            var summary = response.content
            validateAndCleanSummary(&summary, fallback: fallback, snapshot: snapshot)

            AILogger.shared.log(
                type: .routeNarrator,
                input: routeSummaryLogInput(for: snapshot),
                output: summary.title,
                confidence: summary.confidence,
                isSuccess: true
            )
            return summary
        } catch {
            var summary = fallback
            validateAndCleanSummary(&summary, fallback: fallback, snapshot: snapshot)
            AILogger.shared.log(
                type: .routeNarrator,
                input: routeSummaryLogInput(for: snapshot),
                output: summary.title,
                confidence: summary.confidence,
                isSuccess: false,
                error: error
            )
            return summary
        }
    }

    private func isModelReady(_ model: SystemLanguageModel) -> Bool {
        model.availability == .available
    }

    private func supportsPreferredLocale(_ model: SystemLanguageModel) -> Bool {
        model.supportsLocale(Locale(identifier: "ko_KR")) || model.supportsLocale(.current)
    }

    private func normalize(input: OCRContextInput) -> OCRContextInput {
        OCRContextInput(
            rawText: normalizedText(input.rawText),
            topCandidates: deduplicatedQueries(input.topCandidates + extractRoadCandidates(from: input.rawText)),
            localeHint: input.localeHint?.trimmingCharacters(in: .whitespacesAndNewlines),
            neighborPhotoHints: input.neighborPhotoHints.map { hint in
                NeighborHint(
                    direction: hint.direction,
                    roadName: hint.roadName.map { normalizedText($0) },
                    coordinate: hint.coordinate
                )
            }
        )
    }

    private func hasLocationEvidence(in input: OCRContextInput) -> Bool {
        !input.topCandidates.isEmpty || !extractRoadCandidates(from: input.rawText).isEmpty
    }

    private func geocodePrompt(for input: OCRContextInput) -> String {
        let candidates = input.topCandidates.isEmpty
            ? "- 없음"
            : input.topCandidates.map { "- \($0)" }.joined(separator: "\n")

        let neighbors = input.neighborPhotoHints.isEmpty
            ? "- 없음"
            : input.neighborPhotoHints.map { hint in
                let direction = hint.direction == .previous ? "이전" : "다음"
                let road = hint.roadName?.isEmpty == false ? hint.roadName! : "없음"
                let coordinate = hint.coordinate.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? "없음"
                return "- \(direction) 사진: road=\(road), coord=\(coordinate)"
            }.joined(separator: "\n")

        return """
        다음 OCR 컨텍스트를 바탕으로 CLGeocoder에 넣을 한국 주소 질의를 정규화하세요.
        제약:
        - query는 한 줄 검색 질의이며 공백/중복을 정리합니다.
        - 광고 문구, 상호 슬로건, 안내 문구는 제외합니다.
        - 근거가 부족한 행정구역은 추정으로 추가하지 않습니다.
        - alternatives는 최대 3개, query와 중복 없이 제안합니다.
        - reason은 한국어 한 문장으로 설명합니다.

        OCR 원문:
        \(input.rawText.isEmpty ? "(없음)" : input.rawText)

        상위 후보:
        \(candidates)

        지역 힌트:
        \(input.localeHint ?? "없음")

        인접 사진 힌트:
        \(neighbors)
        """
    }

    private func geocodeLogInput(for input: OCRContextInput) -> String {
        if !input.rawText.isEmpty {
            return input.rawText
        }
        return input.topCandidates.joined(separator: ", ")
    }

    private func fallbackGeocodePlan(for input: OCRContextInput) -> GeocodeQueryPlan {
        let candidates = deduplicatedQueries(
            input.topCandidates
            + input.neighborPhotoHints.compactMap(\.roadName)
            + extractRoadCandidates(from: input.rawText)
        )

        let neighborRoads = deduplicatedQueries(input.neighborPhotoHints.compactMap(\.roadName))
        let ranked = candidates.enumerated().map { index, candidate in
            (candidate, heuristicScore(for: candidate, index: index, neighbors: neighborRoads, localeHint: input.localeHint, rawText: input.rawText))
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.count < rhs.0.count
            }
            return lhs.1 > rhs.1
        }

        let query = ranked.first?.0 ?? ""
        let alternatives = ranked.dropFirst().map(\.0).filter { $0 != query }.prefix(3)
        let components = parseAddressComponents(
            from: query,
            localeHint: input.localeHint,
            neighbors: neighborRoads
        )

        let confidence = min(max(ranked.first?.1 ?? 0.35, 0.35), 0.82)
        let reasonParts = [
            neighborRoads.contains(where: { query.contains($0) || $0.contains(query) }) ? "인접 사진의 도로 힌트와 겹치는 후보를 우선했습니다" : nil,
            !input.topCandidates.isEmpty ? "OCR 상위 후보를 기준으로 질의를 정규화했습니다" : nil,
            input.localeHint?.isEmpty == false ? "기기 지역 힌트를 보조 정보로 사용했습니다" : nil
        ].compactMap { $0 }

        return GeocodeQueryPlan(
            query: query,
            components: components,
            confidence: confidence,
            reason: reasonParts.isEmpty ? "OCR 후보를 보수적으로 정리해 지오코딩 질의를 구성했습니다" : reasonParts.joined(separator: ". "),
            alternatives: Array(alternatives)
        )
    }

    private func heuristicScore(
        for candidate: String,
        index: Int,
        neighbors: [String],
        localeHint: String?,
        rawText: String
    ) -> Double {
        var score = max(0.15, 0.9 - Double(index) * 0.12)
        if candidate.contains("고속도로") { score += 0.18 }
        if candidate.contains("대로") || candidate.contains("번길") { score += 0.12 }
        if candidate.range(of: #"\d+(?:-\d+)?"#, options: .regularExpression) != nil { score += 0.05 }
        if neighbors.contains(where: { candidate.contains($0) || $0.contains(candidate) }) { score += 0.18 }
        if let localeHint, !localeHint.isEmpty, candidate.contains(localeHint.replacingOccurrences(of: "_", with: " ")) {
            score += 0.06
        }
        if rawText.contains(candidate) { score += 0.06 }
        return min(score, 0.95)
    }

    private func parseAddressComponents(
        from query: String,
        localeHint: String?,
        neighbors: [String]
    ) -> AddressComponents {
        let tokens = query.split(separator: " ").map(String.init)
        let locationTokens = deduplicatedQueries(([localeHint].compactMap { $0 }) + neighbors)
            .flatMap { $0.split(separator: " ").map(String.init) }

        let province = (tokens + locationTokens).first(where: isProvinceToken(_:))
        let city = (tokens + locationTokens).first(where: isCityToken(_:))
        let district = (tokens + locationTokens).first(where: isDistrictToken(_:))
        let road = tokens.last(where: isRoadToken(_:)) ?? tokens.first(where: isRoadToken(_:))
        let building = tokens.first(where: isBuildingToken(_:))
        let number = query.firstMatch(for: #"\d+(?:-\d+)?"#)

        return AddressComponents(
            province: province,
            city: city,
            district: district,
            road: road,
            building: building,
            number: number
        )
    }

    private func validateAndCleanResult(_ plan: inout GeocodeQueryPlan, fallback: GeocodeQueryPlan) {
        plan.query = normalizedText(plan.query)
        if plan.query.isEmpty {
            plan.query = fallback.query
        }

        plan.reason = normalizedText(plan.reason)
        if plan.reason.isEmpty {
            plan.reason = fallback.reason
        }

        let mergedComponents = merge(
            plan.components,
            with: fallback.components,
            defaultRoad: plan.query.isEmpty ? fallback.query : plan.query
        )
        plan.components = mergedComponents

        plan.confidence = max(0.0, min(1.0, plan.confidence))
        if plan.confidence == 0 {
            plan.confidence = fallback.confidence
        }

        let cleanedAlternatives = deduplicatedQueries(plan.alternatives + fallback.alternatives)
            .filter { $0 != plan.query }
        plan.alternatives = Array(cleanedAlternatives.prefix(3))
    }

    private func merge(
        _ primary: AddressComponents,
        with fallback: AddressComponents,
        defaultRoad: String
    ) -> AddressComponents {
        AddressComponents(
            province: primary.province ?? fallback.province,
            city: primary.city ?? fallback.city,
            district: primary.district ?? fallback.district,
            road: normalizedText(primary.road ?? fallback.road ?? defaultRoad),
            building: primary.building ?? fallback.building,
            number: primary.number ?? fallback.number
        )
    }

    private func routeSummaryPrompt(for snapshot: RouteStatsSnapshot) -> String {
        let roads = snapshot.visitedRoadsTopN.isEmpty ? "없음" : snapshot.visitedRoadsTopN.joined(separator: ", ")
        let areas = snapshot.areaKeywords.isEmpty ? "없음" : snapshot.areaKeywords.prefix(5).joined(separator: ", ")

        return """
        다음 경로 통계를 바탕으로 한국어 RouteSummary를 생성하세요.
        제약:
        - title은 10~24자 정도의 자연스러운 제목
        - caption에는 총 거리(km)와 소요 시간(분)을 반드시 포함
        - diaryEntry는 3~5문장
        - highlights는 2~3개, 각 20자 이내
        - userEditedTitle이 있으면 완전히 무시하지 말고 참고하세요.

        dateRange: \(snapshot.dateRange)
        distanceKm: \(String(format: "%.1f", snapshot.distanceKm))
        durationMin: \(snapshot.durationMin)
        photoCount: \(snapshot.photoCount)
        startName: \(snapshot.startName)
        endName: \(snapshot.endName)
        timeOfDay: \(snapshot.timeOfDay ?? "주간")
        visitedRoadsTopN: \(roads)
        areaKeywords: \(areas)
        userEditedTitle: \(snapshot.userEditedTitle ?? "없음")
        """
    }

    private func routeSummaryLogInput(for snapshot: RouteStatsSnapshot) -> String {
        [
            snapshot.dateRange,
            snapshot.startName,
            snapshot.endName,
            String(format: "%.1fkm", snapshot.distanceKm),
            "\(snapshot.durationMin)분",
            "\(snapshot.photoCount)장"
        ].joined(separator: " | ")
    }

    private func fallbackRouteSummary(for snapshot: RouteStatsSnapshot) -> RouteSummary {
        let distanceText = String(format: "%.1f", snapshot.distanceKm)
        let photoText = "\(snapshot.photoCount)장의 사진"
        let topRoad = shortLabel(from: snapshot.visitedRoadsTopN.first ?? snapshot.areaKeywords.first ?? snapshot.startName)
        let editedTitle = normalizedText(snapshot.userEditedTitle ?? "")
        let titleCandidate = editedTitle.isEmpty
            ? "\(topRoad) \(snapshot.timeOfDay ?? "주간") 기록"
            : editedTitle
        let title = clampedTitle(titleCandidate, fallback: "\(snapshot.timeOfDay ?? "주간") 경로 기록")
        let caption = "약 \(distanceText)km를 \(snapshot.durationMin)분 동안 이동하며 \(photoText)을 남긴 여정."

        let narrativeFocus = snapshot.visitedRoadsTopN.prefix(2).joined(separator: ", ")
        let diaryThirdSentence: String
        if narrativeFocus.isEmpty {
            diaryThirdSentence = "사진의 시간 순서를 따라 이동 흐름이 자연스럽게 이어집니다."
        } else {
            diaryThirdSentence = "\(narrativeFocus) 주변의 흐름이 특히 또렷하게 남았습니다."
        }

        let diary = """
        \(snapshot.timeOfDay ?? "주간")에 \(snapshot.startName)에서 출발해 \(snapshot.endName)까지 이어진 이동이었습니다. \
        총 \(distanceText)km를 \(snapshot.durationMin)분 동안 움직이며 \(photoText)으로 장면을 기록했습니다. \
        \(diaryThirdSentence)
        """

        let highlights = Array(
            NSOrderedSet(array: [
                shortLabel(from: snapshot.timeOfDay ?? "주간 이동"),
                shortLabel(from: topRoad),
                shortLabel(from: "\(snapshot.durationMin)분 기록")
            ])
        ) as? [String] ?? []

        return RouteSummary(
            title: title,
            caption: caption,
            diaryEntry: normalizedText(diary),
            highlights: Array(highlights.prefix(3)).map { String($0.prefix(20)) },
            tone: editedTitle.isEmpty ? .warm : .documentary,
            confidence: 0.62
        )
    }

    private func validateAndCleanSummary(
        _ summary: inout RouteSummary,
        fallback: RouteSummary,
        snapshot: RouteStatsSnapshot
    ) {
        summary.title = clampedTitle(summary.title, fallback: fallback.title)

        let requiredDistance = String(format: "%.1f", snapshot.distanceKm)
        summary.caption = normalizedText(summary.caption)
        if summary.caption.isEmpty {
            summary.caption = fallback.caption
        }
        if !summary.caption.contains(requiredDistance) || !summary.caption.contains("\(snapshot.durationMin)분") {
            summary.caption = "\(summary.caption) \(fallback.caption)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        summary.diaryEntry = normalizedText(summary.diaryEntry)
        if summary.diaryEntry.count < 40 {
            summary.diaryEntry = fallback.diaryEntry
        }

        let uniqueHighlights = Array(NSOrderedSet(array: summary.highlights)) as? [String] ?? summary.highlights
        let cleanedHighlights = uniqueHighlights
            .map(normalizedText)
            .filter { !$0.isEmpty }
            .map { String($0.prefix(20)) }
        summary.highlights = cleanedHighlights.isEmpty ? fallback.highlights : Array(cleanedHighlights.prefix(3))

        summary.confidence = max(0.0, min(1.0, summary.confidence))
        if summary.confidence == 0 {
            summary.confidence = fallback.confidence
        }
    }

    private func deduplicatedQueries(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let normalized = normalizedText(value)
            guard !normalized.isEmpty else { return nil }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return normalized
        }
    }

    private func extractRoadCandidates(from rawText: String) -> [String] {
        rawText.matches(for: #"[가-힣0-9·\.\- ]{2,}(?:고속도로|국도|번길|대로|거리|길|로)(?:\s*\d{1,3}(?:-\d{1,3})?)?"#)
            .map(normalizedText)
            .filter { !$0.isEmpty }
    }

    private func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func shortLabel(from text: String) -> String {
        let cleaned = normalizedText(text)
        let trimmed = cleaned.replacingOccurrences(of: "알 수 없는 ", with: "")
        return String(trimmed.prefix(20))
    }

    private func clampedTitle(_ title: String, fallback: String) -> String {
        let cleaned = normalizedText(title)
        let candidate = cleaned.isEmpty ? fallback : cleaned
        return String(candidate.prefix(24))
    }

    private func isProvinceToken(_ token: String) -> Bool {
        token.hasSuffix("도") || token.hasSuffix("특별시") || token.hasSuffix("광역시") || token.hasSuffix("특별자치시")
    }

    private func isCityToken(_ token: String) -> Bool {
        token.hasSuffix("시") || token.hasSuffix("군")
    }

    private func isDistrictToken(_ token: String) -> Bool {
        token.hasSuffix("구") || token.hasSuffix("읍") || token.hasSuffix("면") || token.hasSuffix("동")
    }

    private func isRoadToken(_ token: String) -> Bool {
        token.hasSuffix("로") || token.hasSuffix("길") || token.hasSuffix("대로") || token.hasSuffix("거리") || token.hasSuffix("고속도로")
    }

    private func isBuildingToken(_ token: String) -> Bool {
        token.hasSuffix("빌딩") || token.hasSuffix("센터") || token.hasSuffix("타워") || token.hasSuffix("아파트")
    }
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { result in
            guard let range = Range(result.range, in: self) else { return nil }
            return String(self[range])
        }
    }

    func firstMatch(for pattern: String) -> String? {
        matches(for: pattern).first
    }
}
