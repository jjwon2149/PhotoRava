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
}

struct ExifStampExportSettings: Codable, Equatable {
    var format: ExifStampExportFormat
    var jpegQuality: Double
    var keepExif: Bool
    /// Batch export concurrency limit. Default is 1 to avoid OOM.
    var batchConcurrencyLimit: Int

    static let `default` = ExifStampExportSettings(
        format: .jpeg,
        jpegQuality: 0.9,
        keepExif: false,
        batchConcurrencyLimit: 1
    )

    init(
        format: ExifStampExportFormat = .jpeg,
        jpegQuality: Double = 0.9,
        keepExif: Bool = false,
        batchConcurrencyLimit: Int = 1
    ) {
        self.format = format
        self.jpegQuality = jpegQuality
        self.keepExif = keepExif
        self.batchConcurrencyLimit = batchConcurrencyLimit
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = try container.decodeIfPresent(ExifStampExportFormat.self, forKey: .format) ?? .jpeg
        self.jpegQuality = try container.decodeIfPresent(Double.self, forKey: .jpegQuality) ?? 0.9
        self.keepExif = try container.decodeIfPresent(Bool.self, forKey: .keepExif) ?? false
        self.batchConcurrencyLimit = try container.decodeIfPresent(Int.self, forKey: .batchConcurrencyLimit) ?? 1
    }
}

struct ExifStampUserSettings: Codable, Equatable {
    var selectedThemeId: String
    var themeOverridesById: [String: ExifStampThemeOverride]
    var exportSettings: ExifStampExportSettings

    static let `default` = ExifStampUserSettings(
        selectedThemeId: ExifStampTheme.twoLine.id,
        themeOverridesById: [:],
        exportSettings: .default
    )

    init(
        selectedThemeId: String,
        themeOverridesById: [String: ExifStampThemeOverride],
        exportSettings: ExifStampExportSettings
    ) {
        self.selectedThemeId = selectedThemeId
        self.themeOverridesById = themeOverridesById
        self.exportSettings = exportSettings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedThemeId = try container.decodeIfPresent(String.self, forKey: .selectedThemeId) ?? ExifStampTheme.twoLine.id
        self.themeOverridesById = try container.decodeIfPresent([String: ExifStampThemeOverride].self, forKey: .themeOverridesById) ?? [:]
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
