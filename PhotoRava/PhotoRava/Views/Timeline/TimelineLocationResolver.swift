//
//  TimelineLocationResolver.swift
//  PhotoRava
//
//  Created by Codex on 1/27/26.
//

import CoreLocation
import Foundation

@MainActor
final class TimelineLocationResolver: ObservableObject {
    private var cache: [String: String] = [:]
    private var inFlight: Set<String> = []
    private let geocoder = CLGeocoder()
    
    func cachedName(latitude: Double, longitude: Double) -> String? {
        cache[key(latitude: latitude, longitude: longitude)]
    }
    
    func resolveIfNeeded(latitude: Double, longitude: Double) async {
        let k = key(latitude: latitude, longitude: longitude)
        if cache[k] != nil { return }
        if inFlight.contains(k) { return }
        
        inFlight.insert(k)
        defer { inFlight.remove(k) }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: .current)
            if let placemark = placemarks.first {
                let name = Self.formatPlacemark(placemark).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    cache[k] = name
                    objectWillChange.send()
                }
            }
        } catch {
            // Ignore reverse geocoding errors; UI falls back to coordinates.
        }
    }
    
    func fallbackCoordinateText(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
    
    private func key(latitude: Double, longitude: Double) -> String {
        // Round to reduce cache fragmentation and repeated lookups.
        let lat = (latitude * 10_000).rounded() / 10_000
        let lon = (longitude * 10_000).rounded() / 10_000
        return "\(lat),\(lon)"
    }
    
    private static func formatPlacemark(_ p: CLPlacemark) -> String {
        // Prefer human-friendly administrative structure.
        // KR example: administrativeArea(시/도) + locality(시/군/구) + subLocality(동)
        var parts: [String] = []
        
        if let administrativeArea = p.administrativeArea, !administrativeArea.isEmpty {
            parts.append(administrativeArea)
        }
        if let locality = p.locality, !locality.isEmpty, !parts.contains(locality) {
            parts.append(locality)
        }
        if let subLocality = p.subLocality, !subLocality.isEmpty, !parts.contains(subLocality) {
            parts.append(subLocality)
        }
        
        if parts.isEmpty, let name = p.name, !name.isEmpty {
            parts.append(name)
        }
        
        return parts.joined(separator: " ")
    }
}

