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
                    
                    // 도로명 패턴 체크
                    let roadPattern = #"[가-힣\s]+(?:로|길|대로)"#
                    guard text.string.range(of: roadPattern, options: .regularExpression) != nil else {
                        return nil
                    }
                    
                    // 숫자 포함 체크 (도로명 표지판에는 보통 번지수가 있음)
                    let hasNumber = text.string.range(of: #"\d+"#, options: .regularExpression) != nil
                    
                    return RecognizedText(
                        text: self.cleanRoadName(text.string),
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
    
    private func cleanRoadName(_ text: String) -> String {
        // 불필요한 공백 제거
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 연속된 공백을 하나로
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // 숫자와 단위 제거 (예: "123-45" 같은 번지수)
        cleaned = cleaned.replacingOccurrences(of: #"\d+[-\d]*"#, with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct RecognizedText {
    let text: String
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


