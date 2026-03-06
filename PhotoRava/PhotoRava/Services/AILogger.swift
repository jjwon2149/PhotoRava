//
//  AILogger.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Foundation
import Combine

/// AI 분석 품질 측정을 위한 로컬 로거
final class AILogger: ObservableObject {
    static let shared = AILogger()
    private init() {}
    
    struct LogEntry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let type: LogType
        let inputSummary: String
        let outputSummary: String
        let confidence: Double
        let isSuccess: Bool
        let error: String?
    }
    
    enum LogType: String, Codable {
        case geocodePlanner
        case routeNarrator
    }
    
    @Published private(set) var logs: [LogEntry] = []
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
            
            // 디버그 출력
            print("🤖 AI LOG [\(type.rawValue)]: \(isSuccess ? "SUCCESS" : "FAIL") (Conf: \(Int(confidence * 100))%)")
        }
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}
