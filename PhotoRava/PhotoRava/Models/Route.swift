//
//  Route.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import SwiftData

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


