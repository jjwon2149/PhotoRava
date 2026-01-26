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
        locale: Locale = .current
    ) -> (line1: String?, line2: String?) {
        let makeModel = [metadata.make, metadata.model]
            .compactMap { $0?.trimmedOrNil() }
            .joined(separator: " ")
            .trimmedOrNil()
        
        let line1: String? = {
            guard var base = makeModel else { return nil }
            if let lens = metadata.lensModel?.trimmedOrNil() {
                base += " • \(lens)"
            }
            return base
        }()
        
        var tokens: [String] = []
        if let iso = metadata.iso {
            tokens.append("ISO \(iso)")
        }
        if let shutter = formatShutter(metadata.exposureTimeSeconds) {
            tokens.append(shutter)
        }
        if let f = metadata.fNumber {
            tokens.append(String(format: "f/%.1f", f))
        }
        if let focal = metadata.focalLengthMm {
            let focalText = focal >= 10 ? String(format: "%.0fmm", focal) : String(format: "%.1fmm", focal)
            tokens.append(focalText)
        }
        
        let dateText: String? = {
            guard let date = metadata.capturedAt else { return nil }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date).trimmedOrNil()
        }()
        
        if let dateText {
            if !tokens.isEmpty {
                tokens.append("•")
            }
            tokens.append(dateText)
        }
        
        let line2 = tokens.joined(separator: "  ").trimmedOrNil()
        
        return (line1: line1, line2: line2)
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

