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
    /// 메타데이터 추출 (PHAsset 우선)
    func extractMetadata(from image: UIImage, asset: PHAsset?, originalData: Data? = nil) async -> PhotoMetadata {
        var metadata = PhotoMetadata()
        
        // 1. PHAsset에서 메타데이터 추출 (우선순위 1 - 가장 신뢰도 높음)
        if let asset = asset {
            // PHAsset의 기본 메타데이터
            metadata.capturedAt = asset.creationDate ?? Date()
            
            if let location = asset.location {
                metadata.coordinate = StoredCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            
            // 원본 이미지 데이터에서 EXIF 추출 (더 정확한 촬영 시간 등)
            if let imageData = await fetchOriginalImageData(for: asset) ?? originalData {
                metadata = extractEXIFMetadata(from: imageData, metadata: metadata)
            }
        } else {
            // 2. 이미지 데이터에서 EXIF 추출 (우선순위 2 - PHAsset 없을 때)
            // 주의: UIImage에서 직접 만든 JPEG는 EXIF가 손실될 수 있음
            if let imageData = originalData ?? image.jpegData(compressionQuality: 1.0) {
                metadata = extractEXIFMetadata(from: imageData, metadata: metadata)
            }
        }
        
        return metadata
    }
    
    /// 원본 이미지 데이터를 메타데이터와 함께 가져오기 (저장용)
    func fetchOriginalImageDataWithMetadata(for asset: PHAsset) async -> (data: Data?, metadata: PhotoMetadata)? {
        let metadata = PhotoMetadata()
        
        // PHAsset 기본 정보
        var resultMetadata = metadata
        resultMetadata.capturedAt = asset.creationDate ?? Date()
        
        if let location = asset.location {
            resultMetadata.coordinate = StoredCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
        
        // 원본 이미지 데이터 가져오기
        guard let imageData = await fetchOriginalImageData(for: asset) else {
            return nil
        }
        
        // EXIF 메타데이터 추출
        resultMetadata = extractEXIFMetadata(from: imageData, metadata: resultMetadata)
        
        return (imageData, resultMetadata)
    }
    
    func fetchOriginalImageData(for asset: PHAsset) async -> Data? {
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

