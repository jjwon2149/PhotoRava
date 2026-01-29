//
//  ExifStampBatchExportState.swift
//  PhotoRava
//
//  Created by Codex on 1/29/26.
//

import Foundation

struct ExifStampBatchExportState: Equatable {
    enum Mode: String, Equatable {
        case saveToPhotos
        case share
    }

    struct ResultItem: Identifiable, Equatable {
        enum Status: String, Equatable {
            case pending
            case success
            case failed
        }

        var index: Int
        var identifier: String
        var status: Status
        var message: String?
        var outputURL: URL?

        var id: Int { index }
    }

    var isRunning: Bool = false
    var mode: Mode? = nil

    var total: Int = 0
    var completed: Int = 0
    var failed: Int = 0

    /// 1-based index of the currently processing item.
    var currentIndex: Int = 0
    var currentIdentifier: String? = nil

    var lastSummary: String? = nil
    var lastFailures: [String] = []
    var results: [ResultItem] = []

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed + failed) / Double(total)
    }
}
