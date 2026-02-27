//
//  ExifStampUserSettings.swift
//  PhotoRava
//
//  Created by Codex on 1/28/26.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

enum ExifStampDateFormatPreset: String, Codable, CaseIterable, Identifiable {
    case locale
    case yyyyMMddSlashes
    case yyyyMMddDots

    var id: String { rawValue }

    var label: String {
        switch self {
        case .locale: return "기본(지역 설정)"
        case .yyyyMMddSlashes: return "yyyy/MM/dd"
        case .yyyyMMddDots: return "yyyy.MM.dd"
        }
    }
}

enum ExifStampExportFormat: String, Codable, CaseIterable, Identifiable {
    case jpeg
    case png
    case heic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .jpeg, .heic: return true
        case .png: return false
        }
    }
}

enum ExifStampExportSize: String, Codable, CaseIterable, Identifiable {
    case original
    case large // 2048px
    case medium // 1080px
    case small // 720px

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "원본"
        case .large: return "대형 (2048px)"
        case .medium: return "중형 (1080px)"
        case .small: return "소형 (720px)"
        }
    }

    func targetLongSide(original: CGFloat) -> CGFloat? {
        switch self {
        case .original: return nil
        case .large: return 2048
        case .medium: return 1080
        case .small: return 720
        }
    }
}

enum ExifStampCanvasRatio: String, Codable, CaseIterable, Identifiable {
    case original
    case square // 1:1
    case portrait4_5 // 4:5
    case portrait2_3 // 2:3
    case landscape3_2 // 3:2
    case landscape16_9 // 16:9

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "원본 비율"
        case .square: return "1:1 (정사각형)"
        case .portrait4_5: return "4:5 (인스타 세로)"
        case .portrait2_3: return "2:3"
        case .landscape3_2: return "3:2"
        case .landscape16_9: return "16:9"
        }
    }

    func ratio(originalSize: CGSize) -> CGFloat? {
        switch self {
        case .original: return nil
        case .square: return 1.0
        case .portrait4_5: return 4.0/5.0
        case .portrait2_3: return 2.0/3.0
        case .landscape3_2: return 3.0/2.0
        case .landscape16_9: return 16.0/9.0
        }
    }
}

struct ExifStampThemeOverride: Codable, Equatable {
    var paddingPreset: ExifStampPaddingPreset? = nil

    /// Padding as a fraction of the shortest image side. `nil` keeps theme defaults.
    var paddingTopFraction: Double? = nil
    var paddingBottomFraction: Double? = nil
    var paddingLeftFraction: Double? = nil
    var paddingRightFraction: Double? = nil

    /// Colors as hex strings. `nil` keeps theme defaults.
    var backgroundColorHex: String? = nil
    var textColorHex: String? = nil

    var textAlignment: ExifStampTextAlignment? = nil
    var textScale: Double? = nil

    var showsMake: Bool? = nil
    var showsModel: Bool? = nil
    var showsLens: Bool? = nil
    var showsISO: Bool? = nil
    var showsShutter: Bool? = nil
    var showsFNumber: Bool? = nil
    var showsFocalLength: Bool? = nil
    var showsDate: Bool? = nil

    var dateFormatPreset: ExifStampDateFormatPreset? = nil
    
    /// Normalized crop rect (0.0 to 1.0). nil means no crop.
    var cropRect: CGRect? = nil
    
    var canvasRatio: ExifStampCanvasRatio? = nil
}

struct ExifStampExportSettings: Codable, Equatable {
    var format: ExifStampExportFormat
    var jpegQuality: Double
    var keepExif: Bool
    /// Batch export concurrency limit. Default is 1 to avoid OOM.
    var batchConcurrencyLimit: Int
    var exportSize: ExifStampExportSize

    static let `default` = ExifStampExportSettings(
        format: .jpeg,
        jpegQuality: 0.9,
        keepExif: false,
        batchConcurrencyLimit: 1,
        exportSize: .original
    )

    init(
        format: ExifStampExportFormat = .jpeg,
        jpegQuality: Double = 0.9,
        keepExif: Bool = false,
        batchConcurrencyLimit: Int = 1,
        exportSize: ExifStampExportSize = .original
    ) {
        self.format = format
        self.jpegQuality = jpegQuality
        self.keepExif = keepExif
        self.batchConcurrencyLimit = batchConcurrencyLimit
        self.exportSize = exportSize
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = try container.decodeIfPresent(ExifStampExportFormat.self, forKey: .format) ?? .jpeg
        self.jpegQuality = try container.decodeIfPresent(Double.self, forKey: .jpegQuality) ?? 0.9
        self.keepExif = try container.decodeIfPresent(Bool.self, forKey: .keepExif) ?? false
        self.batchConcurrencyLimit = try container.decodeIfPresent(Int.self, forKey: .batchConcurrencyLimit) ?? 1
        self.exportSize = try container.decodeIfPresent(ExifStampExportSize.self, forKey: .exportSize) ?? .original
    }
}

struct ExifStampUserSettings: Codable, Equatable {
    var selectedThemeId: String
    var themeOverridesById: [String: ExifStampThemeOverride]
    var photoOverridesById: [String: ExifStampThemeOverride]
    var exportSettings: ExifStampExportSettings

    static let `default` = ExifStampUserSettings(
        selectedThemeId: ExifStampTheme.twoLine.id,
        themeOverridesById: [:],
        photoOverridesById: [:],
        exportSettings: .default
    )

    init(
        selectedThemeId: String,
        themeOverridesById: [String: ExifStampThemeOverride],
        photoOverridesById: [String: ExifStampThemeOverride] = [:],
        exportSettings: ExifStampExportSettings
    ) {
        self.selectedThemeId = selectedThemeId
        self.themeOverridesById = themeOverridesById
        self.photoOverridesById = photoOverridesById
        self.exportSettings = exportSettings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedThemeId = try container.decodeIfPresent(String.self, forKey: .selectedThemeId) ?? ExifStampTheme.twoLine.id
        self.themeOverridesById = try container.decodeIfPresent([String: ExifStampThemeOverride].self, forKey: .themeOverridesById) ?? [:]
        self.photoOverridesById = try container.decodeIfPresent([String: ExifStampThemeOverride].self, forKey: .photoOverridesById) ?? [:]
        self.exportSettings = try container.decodeIfPresent(ExifStampExportSettings.self, forKey: .exportSettings) ?? .default
    }
}

enum ExifStampUserSettingsPersistence {
    static let userDefaultsKey = "ExifStampUserSettings.v1"

    static func load(from defaults: UserDefaults = .standard) -> ExifStampUserSettings {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return .default }
        do {
            return try JSONDecoder().decode(ExifStampUserSettings.self, from: data)
        } catch {
            return .default
        }
    }

    static func save(_ settings: ExifStampUserSettings, to defaults: UserDefaults = .standard) {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: userDefaultsKey)
        } catch {
            // Ignore persistence errors for MVP.
        }
    }
}

extension UIColor {
    convenience init?(exifStampHex: String) {
        var s = exifStampHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }

        let r, g, b, a: CGFloat
        if s.count == 6 {
            r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            g = CGFloat((value & 0x00FF00) >> 8) / 255.0
            b = CGFloat(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = CGFloat((value & 0xFF000000) >> 24) / 255.0
            g = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(value & 0x000000FF) / 255.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    func exifStampHexString(includeAlpha: Bool = true) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            let ri = Int((r * 255.0).rounded())
            let gi = Int((g * 255.0).rounded())
            let bi = Int((b * 255.0).rounded())
            let ai = Int((a * 255.0).rounded())
            if includeAlpha {
                return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
            }
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &a) {
            let wi = Int((white * 255.0).rounded())
            let ai = Int((a * 255.0).rounded())
            if includeAlpha {
                return String(format: "#%02X%02X%02X%02X", wi, wi, wi, ai)
            }
            return String(format: "#%02X%02X%02X", wi, wi, wi)
        }

        return includeAlpha ? "#000000FF" : "#000000"
    }
}
