//
//  OCRService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Vision
import UIKit

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

                    // 1차 후보 필터: 도로명 키워드가 포함된 텍스트만 (스코어링은 별도)
                    guard self.isRoadNameLike(raw) else { return nil }
                    
                    // 숫자 포함 체크 (도로명 표지판에는 보통 번지수가 있음)
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
            
            // 한글 인식 설정
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
        guard !candidates.isEmpty else { return nil }

        var best: (candidate: RecognizedText, score: Double)?

        for candidate in candidates {
            let score = scoreRoadNameCandidate(candidate)
            if let currentBest = best {
                if score > currentBest.score {
                    best = (candidate, score)
                }
            } else {
                best = (candidate, score)
            }
        }

        guard let best, best.score >= 4.5 else { return nil }
        return best.candidate
    }
    
    private func cleanRoadName(_ text: String) -> String {
        // 불필요한 공백 제거
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 연속된 공백을 하나로
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // 괄호/대괄호 안 설명 제거 (예: "(방면)", "[안내]")
        cleaned = cleaned.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)

        // 번지/호수/가격처럼 "공백으로 구분된 숫자"는 제거 (도로명 자체에 포함된 숫자: '로12길'은 유지)
        cleaned = cleaned.replacingOccurrences(of: #"(?<=\s)\d+(?:[-~]\d+)?(?=\s|$)"#, with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRoadNameLike(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        guard !normalized.isEmpty else { return false }

        // 1) 정규식: "한글/숫자/중점" + 도로명 접미사 패턴
        // - 예: 테헤란로, 테헤란로12길, 올림픽대로, 청계천로, 중앙로, 3·1대로
        let roadRegex = #"[가-힣0-9·\.\-]{2,}(?:번길|대로|거리|길|로)(?:[0-9]{1,3})?(?:길)?"#
        if normalized.range(of: roadRegex, options: .regularExpression) != nil {
            return true
        }

        // 2) 키워드 기반 fallback
        // - '로/길'은 일반 단어에도 포함될 수 있어 제외 (예: '프로모션')
        let keywords = ["고속도로", "국도", "번길", "대로", "거리"]
        return keywords.contains(where: { normalized.contains($0) })
    }

    private func scoreRoadNameCandidate(_ candidate: RecognizedText) -> Double {
        let raw = normalize(candidate.rawText)
        let cleaned = normalize(candidate.text)

        guard !raw.isEmpty, !cleaned.isEmpty else { return -Double.greatestFiniteMagnitude }
        guard !containsBlacklistedKeyword(raw) else { return -Double.greatestFiniteMagnitude }

        var score: Double = 0

        // Road keyword weighting (stronger keywords first)
        if cleaned.contains("고속도로") { score += 5 }
        if cleaned.contains("번길") { score += 4 }
        if cleaned.contains("대로") { score += 3.5 }
        if cleaned.contains("국도") { score += 3 }
        if cleaned.contains("거리") { score += 3 }
        if cleaned.hasSuffix("길") { score += 2.5 }
        if cleaned.hasSuffix("로") { score += 2.0 }

        // Length heuristics (favor short road-name like strings)
        let length = cleaned.count
        if (4...18).contains(length) {
            score += 2
        } else if length <= 3 {
            score -= 3
        } else if length > 30 {
            score -= 3
        } else {
            score -= 1
        }

        let ratios = characterRatios(in: raw)
        if ratios.hangul >= 0.7 {
            score += 2
        } else if ratios.hangul >= 0.5 {
            score += 1
        } else {
            score -= 2
        }

        if ratios.digit > 0.4 {
            score -= 2
        } else if ratios.digit > 0.2 {
            score -= 1
        }

        if ratios.special > 0.2 {
            score -= 2
        } else if ratios.special > 0.1 {
            score -= 1
        }

        if candidate.hasNumber {
            score += 0.2
        }

        if let box = candidate.boundingBox {
            score += scoreForBoundingBox(box)
        }

        // Confidence is a tie-breaker, not the main selector
        score += Double(candidate.confidence) * 0.75

        return score
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func containsBlacklistedKeyword(_ text: String) -> Bool {
        let lower = text.lowercased()

        // Currency/price-like patterns
        if lower.range(of: #"\d+\s*(원|만원)"#, options: .regularExpression) != nil {
            return true
        }

        let blacklist = [
            "sale", "open",
            "tel", "call",
            "영업", "할인", "주차", "금연", "주의", "안내", "입구", "출구",
            "문의", "예약", "광고", "무료", "유료", "시간"
        ]
        return blacklist.contains(where: { lower.contains($0.lowercased()) })
    }

    private func characterRatios(in text: String) -> (hangul: Double, digit: Double, special: Double) {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return (0, 0, 0) }

        var hangulCount = 0
        var digitCount = 0
        var specialCount = 0

        for scalar in scalars {
            if scalar.value >= 0xAC00 && scalar.value <= 0xD7A3 {
                hangulCount += 1
            } else if CharacterSet.decimalDigits.contains(scalar) {
                digitCount += 1
            } else if CharacterSet.letters.contains(scalar) {
                // Non-hangul letters are allowed but don't help scoring much
            } else {
                specialCount += 1
            }
        }

        let total = Double(scalars.count)
        return (
            hangul: Double(hangulCount) / total,
            digit: Double(digitCount) / total,
            special: Double(specialCount) / total
        )
    }

    private func scoreForBoundingBox(_ boundingBox: CGRect) -> Double {
        // Vision boundingBox is normalized [0,1] with origin at lower-left.
        // Heuristics: road signs tend to be wide-ish text blocks, often near center-ish.
        guard boundingBox.width > 0, boundingBox.height > 0 else { return 0 }

        var score: Double = 0

        let aspect = boundingBox.width / boundingBox.height
        if aspect >= 2.0 { score += 0.8 }
        if aspect >= 3.0 { score += 0.4 }

        // Favor medium-sized text blocks; penalize tiny detections
        let area = boundingBox.width * boundingBox.height
        if area >= 0.02 { score += 0.4 }
        if area < 0.005 { score -= 0.6 }

        // Center proximity (0.5, 0.5)
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        let dx = abs(centerX - 0.5)
        let dy = abs(centerY - 0.5)
        let centerDistance = min(1.0, (dx + dy) / 1.0)
        score += (1.0 - centerDistance) * 0.4

        return score
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
        case .invalidImage:
            return "유효하지 않은 이미지입니다."
        case .noTextFound:
            return "텍스트를 찾을 수 없습니다."
        }
    }
}
