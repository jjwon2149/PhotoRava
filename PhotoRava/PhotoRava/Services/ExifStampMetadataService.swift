//
//  ExifStampMetadataService.swift
//  PhotoRava
//
//  Created by Codex on 1/27/26.
//

import Foundation
import ImageIO
import Photos

struct ExifStampMetadata: Equatable {
    var capturedAt: Date?
    var make: String?
    var model: String?
    var lensModel: String?
    var iso: Int?
    var exposureTimeSeconds: Double?
    var fNumber: Double?
    var focalLengthMm: Double?
}

final class ExifStampMetadataService {
    static let shared = ExifStampMetadataService()
    private init() {}

    struct CaptionVisibility: Equatable {
        var showsMake: Bool
        var showsModel: Bool
        var showsLens: Bool
        var showsISO: Bool
        var showsShutter: Bool
        var showsFNumber: Bool
        var showsFocalLength: Bool
        var showsDate: Bool
    }
    
    func extract(from imageData: Data, fallbackAsset: PHAsset?) -> ExifStampMetadata {
        var result = ExifStampMetadata()
        result.capturedAt = fallbackAsset?.creationDate
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return result
        }
        
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            result.make = (tiff[kCGImagePropertyTIFFMake as String] as? String)?.trimmedOrNil()
            result.model = (tiff[kCGImagePropertyTIFFModel as String] as? String)?.trimmedOrNil()
        }
        
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
               let parsed = Self.parseExifDate(dateTimeOriginal) {
                result.capturedAt = parsed
            }
            
            if let lens = exif[kCGImagePropertyExifLensModel as String] as? String {
                result.lensModel = lens.trimmedOrNil()
            }
            
            if result.lensModel == nil,
               let aux = properties[kCGImagePropertyExifAuxDictionary as String] as? [String: Any],
               let auxLens = aux[kCGImagePropertyExifAuxLensModel as String] as? String {
                result.lensModel = auxLens.trimmedOrNil()
            }
            
            result.exposureTimeSeconds = Self.numberAsDouble(exif[kCGImagePropertyExifExposureTime as String])
            result.fNumber = Self.numberAsDouble(exif[kCGImagePropertyExifFNumber as String])
            result.focalLengthMm = Self.numberAsDouble(exif[kCGImagePropertyExifFocalLength as String])
            
            if let isoAny = exif[kCGImagePropertyExifISOSpeedRatings as String] {
                result.iso = Self.extractISO(isoAny)
            }
        }
        
        return result
    }
    
    static func formatCaptionLines(
        metadata: ExifStampMetadata,
        layout: ExifStampLayout,
        visibility: CaptionVisibility,
        dateFormatPreset: ExifStampDateFormatPreset,
        locale: Locale = .current
    ) -> (line1: String?, line2: String?) {
        switch layout {
        case .justFrame, .noFrame:
            return (nil, nil)
        case .twoLine:
            return formatTwoLine(metadata: metadata, visibility: visibility, dateFormatPreset: dateFormatPreset, locale: locale)
        case .simpleOneLine:
            return (formatOneLine(metadata: metadata, visibility: visibility, dateFormatPreset: dateFormatPreset, locale: locale), nil)
        case .shotOnOneLine:
            return (formatShotOnOneLine(metadata: metadata, visibility: visibility, dateFormatPreset: dateFormatPreset, locale: locale), nil)
        case .film, .monitor:
            return formatTwoLine(metadata: metadata, visibility: visibility, dateFormatPreset: dateFormatPreset, locale: locale)
        }
    }

    private static func formatTwoLine(
        metadata: ExifStampMetadata,
        visibility: CaptionVisibility,
        dateFormatPreset: ExifStampDateFormatPreset,
        locale: Locale
    ) -> (line1: String?, line2: String?) {
        var line1Parts: [String] = []
        if visibility.showsMake, let make = metadata.make?.trimmedOrNil() {
            line1Parts.append(make)
        }
        if visibility.showsModel, let model = metadata.model?.trimmedOrNil() {
            line1Parts.append(model)
        }
        var line1 = line1Parts.joined(separator: " ").trimmedOrNil()
        if visibility.showsLens, let lens = metadata.lensModel?.trimmedOrNil() {
            if let existing = line1, !existing.isEmpty {
                line1 = "\(existing) • \(lens)"
            } else {
                line1 = lens
            }
        }

        var tokens: [String] = []
        if visibility.showsISO, let iso = metadata.iso {
            tokens.append("ISO \(iso)")
        }
        if visibility.showsShutter, let shutter = formatShutter(metadata.exposureTimeSeconds) {
            tokens.append(shutter)
        }
        if visibility.showsFNumber, let f = metadata.fNumber {
            tokens.append(String(format: "f/%.1f", f))
        }
        if visibility.showsFocalLength, let focal = metadata.focalLengthMm {
            let focalText = focal >= 10 ? String(format: "%.0fmm", focal) : String(format: "%.1fmm", focal)
            tokens.append(focalText)
        }

        if visibility.showsDate, let dateText = formatDate(metadata.capturedAt, dateFormatPreset: dateFormatPreset, locale: locale) {
            if !tokens.isEmpty { tokens.append("•") }
            tokens.append(dateText)
        }

        let line2 = tokens.joined(separator: "  ").trimmedOrNil()
        return (line1: line1, line2: line2)
    }

    private static func formatOneLine(
        metadata: ExifStampMetadata,
        visibility: CaptionVisibility,
        dateFormatPreset: ExifStampDateFormatPreset,
        locale: Locale
    ) -> String? {
        var segments: [String] = []

        var makeModelParts: [String] = []
        if visibility.showsMake, let make = metadata.make?.trimmedOrNil() {
            makeModelParts.append(make)
        }
        if visibility.showsModel, let model = metadata.model?.trimmedOrNil() {
            makeModelParts.append(model)
        }
        let makeModel = makeModelParts.joined(separator: " ").trimmedOrNil()
        if let makeModel { segments.append(makeModel) }

        if visibility.showsLens, let lens = metadata.lensModel?.trimmedOrNil() {
            segments.append(lens)
        }

        var tokens: [String] = []
        if visibility.showsISO, let iso = metadata.iso {
            tokens.append("ISO \(iso)")
        }
        if visibility.showsShutter, let shutter = formatShutter(metadata.exposureTimeSeconds) {
            tokens.append(shutter)
        }
        if visibility.showsFNumber, let f = metadata.fNumber {
            tokens.append(String(format: "f/%.1f", f))
        }
        if visibility.showsFocalLength, let focal = metadata.focalLengthMm {
            let focalText = focal >= 10 ? String(format: "%.0fmm", focal) : String(format: "%.1fmm", focal)
            tokens.append(focalText)
        }
        let exposure = tokens.joined(separator: "  ").trimmedOrNil()
        if let exposure { segments.append(exposure) }

        if visibility.showsDate, let dateText = formatDate(metadata.capturedAt, dateFormatPreset: dateFormatPreset, locale: locale) {
            segments.append(dateText)
        }

        return segments.joined(separator: " • ").trimmedOrNil()
    }

    private static func formatShotOnOneLine(
        metadata: ExifStampMetadata,
        visibility: CaptionVisibility,
        dateFormatPreset: ExifStampDateFormatPreset,
        locale: Locale
    ) -> String? {
        var makeModelParts: [String] = []
        if visibility.showsMake, let make = metadata.make?.trimmedOrNil() {
            makeModelParts.append(make)
        }
        if visibility.showsModel, let model = metadata.model?.trimmedOrNil() {
            makeModelParts.append(model)
        }
        let makeModel = makeModelParts.joined(separator: " ").trimmedOrNil()

        var segments: [String] = []
        if let makeModel {
            segments.append("Shot on \(makeModel)")
        }

        if visibility.showsLens, let lens = metadata.lensModel?.trimmedOrNil() {
            segments.append(lens)
        }

        var tokens: [String] = []
        if visibility.showsISO, let iso = metadata.iso {
            tokens.append("ISO \(iso)")
        }
        if visibility.showsShutter, let shutter = formatShutter(metadata.exposureTimeSeconds) {
            tokens.append(shutter)
        }
        if visibility.showsFNumber, let f = metadata.fNumber {
            tokens.append(String(format: "f/%.1f", f))
        }
        if visibility.showsFocalLength, let focal = metadata.focalLengthMm {
            let focalText = focal >= 10 ? String(format: "%.0fmm", focal) : String(format: "%.1fmm", focal)
            tokens.append(focalText)
        }
        let exposure = tokens.joined(separator: "  ").trimmedOrNil()
        if let exposure { segments.append(exposure) }

        if visibility.showsDate, let dateText = formatDate(metadata.capturedAt, dateFormatPreset: dateFormatPreset, locale: locale) {
            segments.append(dateText)
        }

        return segments.joined(separator: " • ").trimmedOrNil()
    }

    private static func formatDate(_ date: Date?, dateFormatPreset: ExifStampDateFormatPreset, locale: Locale) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        switch dateFormatPreset {
        case .locale:
            formatter.locale = locale
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .yyyyMMddSlashes:
            formatter.locale = locale
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy/MM/dd"
        case .yyyyMMddDots:
            formatter.locale = locale
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy.MM.dd"
        }
        return formatter.string(from: date).trimmedOrNil()
    }
    
    private static func extractISO(_ any: Any) -> Int? {
        if let array = any as? [Any] {
            return extractISO(array.first as Any)
        }
        if let num = any as? NSNumber {
            return Int(truncating: num)
        }
        if let int = any as? Int {
            return int
        }
        if let double = any as? Double {
            return Int(double.rounded())
        }
        return nil
    }
    
    private static func numberAsDouble(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        return nil
    }
    
    private static func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
    
    private static func formatShutter(_ seconds: Double?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        if seconds >= 1 {
            if seconds >= 10 {
                return String(format: "%.0fs", seconds)
            }
            return String(format: "%.1fs", seconds)
        }
        
        let denominator = Int((1.0 / seconds).rounded())
        if denominator > 0 {
            return "1/\(denominator)s"
        }
        return nil
    }
}

private extension String {
    func trimmedOrNil() -> String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
