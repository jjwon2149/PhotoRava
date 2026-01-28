//
//  RouteSnapshotRenderer.swift
//  PhotoRava
//
//  Created by Codex on 1/28/26.
//

import MapKit
import UIKit

enum RouteSnapshotRenderer {
    static func renderSnapshot(
        route: Route,
        size: CGSize,
        scale: CGFloat,
        lineWidth: CGFloat = 6,
        lineColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.95)
    ) async throws -> UIImage {
        guard let coordinatesData = route.coordinatesData,
              let stored = try? JSONDecoder().decode([StoredCoordinate].self, from: coordinatesData) else {
            throw RouteSnapshotError.missingCoordinates
        }

        let coordinates = stored.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard !coordinates.isEmpty else {
            throw RouteSnapshotError.missingCoordinates
        }

        let region = calculateRegion(for: coordinates)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = scale

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)

            guard coordinates.count >= 2 else { return }

            let path = UIBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = lineWidth

            let points = coordinates.map { snapshot.point(for: $0) }
            path.move(to: points[0])
            for p in points.dropFirst() {
                path.addLine(to: p)
            }

            lineColor.setStroke()
            path.stroke()

            drawMarker(at: points.first!, fill: .systemGreen, letter: "S")
            drawMarker(at: points.last!, fill: .systemRed, letter: "E")

            func drawMarker(at point: CGPoint, fill: UIColor, letter: String) {
                let outer = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
                let inner = CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)

                ctx.cgContext.setFillColor(fill.cgColor)
                ctx.cgContext.fillEllipse(in: inner)

                ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                ctx.cgContext.setLineWidth(3)
                ctx.cgContext.strokeEllipse(in: outer)

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let text = NSAttributedString(string: letter, attributes: attrs)
                let size = text.size()
                let rect = CGRect(
                    x: point.x - size.width / 2,
                    y: point.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                text.draw(in: rect)
            }
        }
    }

    private static func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let spanLat = max((maxLat - minLat) * 1.5, 0.01)
        let spanLon = max((maxLon - minLon) * 1.5, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

enum RouteSnapshotError: Error {
    case missingCoordinates
}

