//
//  PhotoMetadataService.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import Photos
import CoreLocation
import ImageIO
import UIKit

class PhotoMetadataService {
    func extractMetadata(from image: UIImage, asset: PHAsset?) async -> PhotoMetadata {
        var metadata = PhotoMetadata()
        
        // 1. PHAsset에서 메타데이터 추출 (우선순위 1)
        if let asset = asset {
            metadata.capturedAt = asset.creationDate ?? Date()
            
            if let location = asset.location {
                metadata.coordinate = StoredCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            
            // 원본 이미지 데이터 가져오기
            if let imageData = await fetchOriginalImageData(for: asset) {
                metadata = extractEXIFMetadata(from: imageData, metadata: metadata)
            }
        } else {
            // 2. 이미지 데이터에서 EXIF 추출 (우선순위 2)
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                metadata = extractEXIFMetadata(from: imageData, metadata: metadata)
            }
        }
        
        return metadata
    }
    
    private func fetchOriginalImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .original
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
    
    private func extractEXIFMetadata(from imageData: Data, metadata: PhotoMetadata) -> PhotoMetadata {
        var result = metadata
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return result
        }
        
        // EXIF DateTime 추출
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateTimeString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                if let date = parseEXIFDate(dateTimeString) {
                    result.capturedAt = date
                }
            }
        }
        
        // GPS 정보 추출
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
               let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double,
               let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String {
                
                let finalLat = latRef == "S" ? -latitude : latitude
                let finalLon = lonRef == "W" ? -longitude : longitude
                
                result.coordinate = StoredCoordinate(latitude: finalLat, longitude: finalLon)
            }
        }
        
        return result
    }
    
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
}

struct PhotoMetadata {
    var capturedAt: Date = Date()
    var coordinate: StoredCoordinate?
    
    var hasGPS: Bool {
        coordinate != nil
    }
}

