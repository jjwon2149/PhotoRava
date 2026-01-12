//
//  PhotoRecord.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import SwiftData

@Model
class PhotoRecord {
    var id: UUID
    var imageData: Data?
    var capturedAt: Date
    var roadName: String?
    var latitude: Double?
    var longitude: Double?
    var ocrConfidence: Float
    
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
}

