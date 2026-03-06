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
        pathCoordinates: [CLLocationCoordinate2D]? = nil,
        size: CGSize,
        scale: CGFloat,
        lineWidth: CGFloat = 6,
        lineColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.95)
    ) async throws -> UIImage {
        let coordinates: [CLLocationCoordinate2D]
        if let pathCoordinates, !pathCoordinates.isEmpty {
            coordinates = pathCoordinates
        } else if let coordinatesData = route.coordinatesData,
                  let stored = try? JSONDecoder().decode([StoredCoordinate].self, from: coordinatesData) {
            coordinates = stored.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        } else {
            throw RouteSnapshotError.missingCoordinates
        }

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
            drawSummaryPanel(in: ctx.cgContext, route: route, size: size)

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

    private static func drawSummaryPanel(in context: CGContext, route: Route, size: CGSize) {
        let title = route.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = route.aiSummaryCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stats = "\(String(format: "%.1f", route.totalDistance)) km · \(Int(route.duration / 60)) min"

        guard !title.isEmpty || !caption.isEmpty else { return }

        let horizontalPadding = size.width * 0.06
        let bottomPadding = size.height * 0.06
        let panelWidth = size.width - (horizontalPadding * 2)
        let panelHeight = caption.isEmpty ? size.height * 0.12 : size.height * 0.19
        let panelRect = CGRect(
            x: horizontalPadding,
            y: size.height - panelHeight - bottomPadding,
            width: panelWidth,
            height: panelHeight
        )

        context.saveGState()
        let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 36)
        context.setFillColor(UIColor.black.withAlphaComponent(0.58).cgColor)
        context.addPath(panelPath.cgPath)
        context.fillPath()
        context.restoreGState()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size.width * 0.04, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let captionParagraph = NSMutableParagraphStyle()
        captionParagraph.lineBreakMode = .byWordWrapping
        captionParagraph.lineSpacing = 6
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size.width * 0.023, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.92),
            .paragraphStyle: captionParagraph
        ]

        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: size.width * 0.022, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.84)
        ]

        let contentX = panelRect.minX + 44
        var currentY = panelRect.minY + 32

        NSString(string: title).draw(
            in: CGRect(x: contentX, y: currentY, width: panelRect.width - 88, height: 54),
            withAttributes: titleAttributes
        )
        currentY += 58

        if !caption.isEmpty {
            let captionRect = CGRect(x: contentX, y: currentY, width: panelRect.width - 88, height: panelRect.height * 0.42)
            NSString(string: caption).draw(with: captionRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: captionAttributes, context: nil)
            currentY = captionRect.maxY + 8
        }

        NSString(string: stats).draw(
            in: CGRect(x: contentX, y: panelRect.maxY - 46, width: panelRect.width - 88, height: 32),
            withAttributes: statsAttributes
        )
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
