//
//  PhotoRecord.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import SwiftData
import CoreLocation
import FoundationModels

@Model
class PhotoRecord {
    var id: UUID
    var imageData: Data?
    var capturedAt: Date
    var roadName: String?
    var latitude: Double?
    var longitude: Double?
    var ocrConfidence: Float
    
    // OCR 분석 원본 데이터 (AI Context용)
    var rawOCRText: String?
    var topOCRCandidates: [String] = []
    
    // AI (Foundation Models) 관련 데이터
    var aiQuery: String?
    var aiConfidence: Double?
    var aiReason: String?
    var aiAlternatives: [String] = []
    
    init(capturedAt: Date) {
        self.id = UUID()
        self.capturedAt = capturedAt
        self.ocrConfidence = 0
    }
}

// MapKit 좌표를 위한 Codable 구조체
struct StoredCoordinate: Codable {
    var latitude: Double
    var longitude: Double
    
    // AI 경로 최적화 (Anomaly Detection) 정보
    var isOptimized: Bool? = false
    var isAnomaly: Bool? = false
}

// MARK: - AI Support Types

/// Foundation Model을 통해 생성된 지오코딩 쿼리 계획
@available(iOS 26.0, *)
@Generable
struct GeocodeQueryPlan {
    @Guide(description: "CLGeocoder에 넣을 최종 정규화된 한국 주소 질의. 비워두지 말 것.")
    var query: String

    var components: AddressComponents

    @Guide(description: "0.0(확신 없음)~1.0(확신) 범위의 신뢰도")
    var confidence: Double

    @Guide(description: "이 후보를 선택한 근거. 디버깅 및 UI 설명용.")
    var reason: String

    @Guide(description: "대체 지오코딩 질의 2~3개. query와 중복 제거.")
    var alternatives: [String]
}

/// 정규화된 주소 구성 요소
@available(iOS 26.0, *)
@Generable
struct AddressComponents {
    var province: String?   // 시/도
    var city: String?       // 시/군/구
    var district: String?   // 읍/면/동
    var road: String?       // 도로명
    var building: String?   // 건물명
    var number: String?     // 건물번호
}

/// LLM 입력을 위한 OCR 컨텍스트 데이터
struct OCRContextInput {
    var rawText: String                  // OCR 원문
    var topCandidates: [String]          // 규칙 기반 상위 후보
    var localeHint: String?              // 기기 지역 또는 지도 현재 뷰 기반 힌트
    var neighborPhotoHints: [NeighborHint] // 이웃 사진 컨텍스트
}

/// 이웃 사진의 위치 힌트
struct NeighborHint {
    var direction: NeighborDirection     // .previous / .next
    var roadName: String?
    var coordinate: CLLocationCoordinate2D?
}

enum NeighborDirection { case previous, next }
