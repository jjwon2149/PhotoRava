import CoreLocation
import Foundation

struct RouteGeometryInput {
    let capturedAt: Date
    let latitude: Double?
    let longitude: Double?
    let roadName: String?
    let fallbackRoadName: String?
}

struct RouteGeometryResult {
    let coordinates: [StoredCoordinate]
    let distanceKilometers: Double
    let duration: TimeInterval
    let roadNames: [String]
}

enum RouteGeometryCalculator {
    static func calculate(from inputs: [RouteGeometryInput]) -> RouteGeometryResult {
        let sortedInputs = inputs.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.capturedAt == rhs.element.capturedAt {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.capturedAt < rhs.element.capturedAt
            }
            .map(\.element)

        let coordinates = sortedInputs.compactMap { input -> StoredCoordinate? in
            guard let latitude = input.latitude,
                  let longitude = input.longitude,
                  latitude.isFinite,
                  longitude.isFinite,
                  (-90.0...90.0).contains(latitude),
                  (-180.0...180.0).contains(longitude) else {
                return nil
            }

            return StoredCoordinate(latitude: latitude, longitude: longitude)
        }

        let distance = zip(coordinates, coordinates.dropFirst()).reduce(0.0) { partialResult, pair in
            let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partialResult + start.distance(from: end) / 1_000.0
        }

        let duration: TimeInterval
        if let first = sortedInputs.first?.capturedAt, let last = sortedInputs.last?.capturedAt {
            duration = max(0, last.timeIntervalSince(first))
        } else {
            duration = 0
        }

        var seenRoadNames: Set<String> = []
        let roadNames = sortedInputs.compactMap { input in
            normalized(input.roadName) ?? normalized(input.fallbackRoadName)
        }
        .filter { seenRoadNames.insert($0).inserted }
        .sorted()

        return RouteGeometryResult(
            coordinates: coordinates,
            distanceKilometers: distance,
            duration: duration,
            roadNames: roadNames
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func summaryDistanceMatches(_ text: String, distanceKilometers: Double) -> Bool {
        guard let distanceRange = text.range(
            of: #"(?<![\d.])\d+(?:\.\d+)?\s*km"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return true
        }

        let distanceText = text[distanceRange]
            .replacingOccurrences(of: "km", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let summarizedDistance = Double(distanceText) else { return true }
        return abs(summarizedDistance - distanceKilometers) < 0.05
    }
}
