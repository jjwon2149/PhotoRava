//
//  ExifStampTheme.swift
//  PhotoRava
//
//  Created by Codex on 1/28/26.
//

import Foundation

enum ExifStampLayout: String, Codable, CaseIterable, Identifiable {
    case twoLine
    case simpleOneLine
    case shotOnOneLine
    case justFrame
    case noFrame
    case film
    case monitor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .twoLine: return "Two line"
        case .simpleOneLine: return "One line"
        case .shotOnOneLine: return "Shot on"
        case .justFrame: return "Just frame"
        case .noFrame: return "No frame"
        case .film: return "Film"
        case .monitor: return "Monitor"
        }
    }

    var supportsCaption: Bool {
        switch self {
        case .justFrame, .noFrame:
            return false
        case .twoLine, .simpleOneLine, .shotOnOneLine, .film, .monitor:
            return true
        }
    }
}

enum ExifStampPaddingPreset: String, Codable, CaseIterable, Identifiable {
    case none
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "없음"
        case .small: return "작게"
        case .medium: return "중간"
        case .large: return "크게"
        }
    }

    /// Base padding as a fraction of the shortest image side.
    var baseFraction: Double {
        switch self {
        case .none: return 0
        case .small: return 0.04
        case .medium: return 0.07
        case .large: return 0.10
        }
    }
}

struct ExifStampThemeDefaults: Codable, Equatable {
    var paddingPreset: ExifStampPaddingPreset
    var backgroundColorHex: String
    var textColorHex: String
    var textAlignment: ExifStampTextAlignment
    var textScale: Double

    var showsMake: Bool
    var showsModel: Bool
    var showsLens: Bool
    var showsISO: Bool
    var showsShutter: Bool
    var showsFNumber: Bool
    var showsFocalLength: Bool
    var showsDate: Bool

    var dateFormatPreset: ExifStampDateFormatPreset
}

struct ExifStampThemeCustomizationSchema: Equatable {
    var allowsPaddingPreset: Bool
    var allowsAdvancedPadding: Bool
    var allowsBackgroundColor: Bool
    var allowsTextColor: Bool
    var allowsTextAlignment: Bool
    var allowsTextScale: Bool
}

struct ExifStampTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let layout: ExifStampLayout
    let defaults: ExifStampThemeDefaults
    let customizationSchema: ExifStampThemeCustomizationSchema
}

extension ExifStampTheme {
    static let twoLine = ExifStampTheme(
        id: "twoLine",
        displayName: "Two line",
        layout: .twoLine,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .medium,
            backgroundColorHex: "#FFFFFFFF",
            textColorHex: "#000000FF",
            textAlignment: .center,
            textScale: 1.25,
            showsMake: true,
            showsModel: true,
            showsLens: true,
            showsISO: true,
            showsShutter: true,
            showsFNumber: true,
            showsFocalLength: true,
            showsDate: true,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: true,
            allowsTextAlignment: true,
            allowsTextScale: true
        )
    )

    static let simpleOneLine = ExifStampTheme(
        id: "simpleOneLine",
        displayName: "One line",
        layout: .simpleOneLine,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .medium,
            backgroundColorHex: "#FFFFFFFF",
            textColorHex: "#000000FF",
            textAlignment: .center,
            textScale: 1.15,
            showsMake: true,
            showsModel: true,
            showsLens: true,
            showsISO: true,
            showsShutter: true,
            showsFNumber: true,
            showsFocalLength: true,
            showsDate: true,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: true,
            allowsTextAlignment: true,
            allowsTextScale: true
        )
    )

    static let justFrame = ExifStampTheme(
        id: "justFrame",
        displayName: "Just frame",
        layout: .justFrame,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .medium,
            backgroundColorHex: "#FFFFFFFF",
            textColorHex: "#000000FF",
            textAlignment: .center,
            textScale: 1.0,
            showsMake: false,
            showsModel: false,
            showsLens: false,
            showsISO: false,
            showsShutter: false,
            showsFNumber: false,
            showsFocalLength: false,
            showsDate: false,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: false,
            allowsTextAlignment: false,
            allowsTextScale: false
        )
    )

    static let noFrame = ExifStampTheme(
        id: "noFrame",
        displayName: "No frame",
        layout: .noFrame,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .none,
            backgroundColorHex: "#FFFFFFFF",
            textColorHex: "#000000FF",
            textAlignment: .center,
            textScale: 1.0,
            showsMake: false,
            showsModel: false,
            showsLens: false,
            showsISO: false,
            showsShutter: false,
            showsFNumber: false,
            showsFocalLength: false,
            showsDate: false,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: false,
            allowsAdvancedPadding: false,
            allowsBackgroundColor: false,
            allowsTextColor: false,
            allowsTextAlignment: false,
            allowsTextScale: false
        )
    )

    static let shotOnOneLine = ExifStampTheme(
        id: "shotOnOneLine",
        displayName: "Shot on",
        layout: .shotOnOneLine,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .medium,
            backgroundColorHex: "#FFFFFFFF",
            textColorHex: "#000000FF",
            textAlignment: .center,
            textScale: 1.15,
            showsMake: true,
            showsModel: true,
            showsLens: true,
            showsISO: true,
            showsShutter: true,
            showsFNumber: true,
            showsFocalLength: true,
            showsDate: true,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: true,
            allowsTextAlignment: true,
            allowsTextScale: true
        )
    )

    static let film = ExifStampTheme(
        id: "film",
        displayName: "Film",
        layout: .film,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .large,
            backgroundColorHex: "#F5F1E9FF",
            textColorHex: "#1A1A1AFF",
            textAlignment: .center,
            textScale: 1.05,
            showsMake: true,
            showsModel: true,
            showsLens: true,
            showsISO: true,
            showsShutter: true,
            showsFNumber: true,
            showsFocalLength: true,
            showsDate: true,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: true,
            allowsTextAlignment: true,
            allowsTextScale: true
        )
    )

    static let monitor = ExifStampTheme(
        id: "monitor",
        displayName: "Monitor",
        layout: .monitor,
        defaults: ExifStampThemeDefaults(
            paddingPreset: .large,
            backgroundColorHex: "#0B0B0BFF",
            textColorHex: "#F2F2F2FF",
            textAlignment: .center,
            textScale: 1.10,
            showsMake: true,
            showsModel: true,
            showsLens: true,
            showsISO: true,
            showsShutter: true,
            showsFNumber: true,
            showsFocalLength: true,
            showsDate: true,
            dateFormatPreset: .locale
        ),
        customizationSchema: ExifStampThemeCustomizationSchema(
            allowsPaddingPreset: true,
            allowsAdvancedPadding: true,
            allowsBackgroundColor: true,
            allowsTextColor: true,
            allowsTextAlignment: true,
            allowsTextScale: true
        )
    )

    static let builtInThemes: [ExifStampTheme] = [
        .twoLine,
        .simpleOneLine,
        .shotOnOneLine,
        .justFrame,
        .noFrame,
        .film,
        .monitor
    ]

    static func theme(for id: String?) -> ExifStampTheme {
        guard let id else { return .twoLine }
        return builtInThemes.first(where: { $0.id == id }) ?? .twoLine
    }
}
