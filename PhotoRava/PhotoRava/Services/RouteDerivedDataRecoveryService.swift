import Foundation
import OSLog
import SwiftData

@MainActor
final class RouteDerivedDataRecoveryService {
    static let shared = RouteDerivedDataRecoveryService()

    private let logger = Logger(subsystem: "PhotoRava", category: "RouteDerivedDataRecovery")
    private let saveContext: (ModelContext) throws -> Void

    init(saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.saveContext = saveContext
    }

    @discardableResult
    func recoverOptimizedRoutes(in container: ModelContainer) async throws -> RouteRecoveryReport {
        let candidateIDs: [UUID]
        do {
            candidateIDs = try await candidateRouteIDs(in: container)
        } catch {
            if error is CancellationError || Task.isCancelled {
                throw CancellationError()
            }
            log(error, message: "Could not inspect routes for derived-data recovery")
            return RouteRecoveryReport(inspectedCount: 0, repairedCount: 0, skippedCount: 0, failedCount: 1)
        }

        var report = RouteRecoveryReport(inspectedCount: candidateIDs.count)
        for routeID in candidateIDs {
            try Task.checkCancellation()
            switch recoverRoute(id: routeID, in: container) {
            case .repaired:
                report.repairedCount += 1
            case .skipped:
                report.skippedCount += 1
            case .failed:
                report.failedCount += 1
            }
            await Task.yield()
        }
        return report
    }

    private func recoverRoute(id: UUID, in container: ModelContainer) -> RecoveryOutcome {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let descriptor = FetchDescriptor<Route>(predicate: #Predicate { $0.id == id })

        do {
            guard let route = try context.fetch(descriptor).first,
                  let oldCoordinates = Self.optimizedCoordinates(route.coordinatesData) else {
                return .skipped
            }

            let inputs = route.photoRecords.map {
                RouteGeometryInput(
                    capturedAt: $0.capturedAt,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    roadName: $0.roadName,
                    fallbackRoadName: $0.aiQuery
                )
            }
            let result = RouteGeometryCalculator.calculate(from: inputs)

            guard !result.coordinates.isEmpty,
                  result.coordinates.count == oldCoordinates.count else {
                logger.notice("Skipped a route whose original coordinates are unavailable")
                return .skipped
            }

            route.photoRecords = route.photoRecords.enumerated()
                .sorted { lhs, rhs in
                    if lhs.element.capturedAt == rhs.element.capturedAt {
                        return lhs.offset < rhs.offset
                    }
                    return lhs.element.capturedAt < rhs.element.capturedAt
                }
                .map(\.element)
            route.coordinatesData = try JSONEncoder().encode(result.coordinates)
            route.totalDistance = result.distanceKilometers
            route.duration = result.duration
            route.roadNames = result.roadNames
            try saveContext(context)
            return .repaired
        } catch {
            context.rollback()
            log(error, message: "Could not repair one route's derived data; it will be retried")
            return .failed
        }
    }

    private func candidateRouteIDs(in container: ModelContainer) async throws -> [UUID] {
        var candidateIDs: [UUID] = []
        var offset = 0
        let batchSize = 50

        while true {
            try Task.checkCancellation()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            var descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\Route.date)])
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            let batch = try context.fetch(descriptor)

            candidateIDs.append(contentsOf: batch.compactMap { route in
                Self.optimizedCoordinates(route.coordinatesData) == nil ? nil : route.id
            })

            guard batch.count == batchSize else { break }
            offset += batchSize
            await Task.yield()
        }

        return candidateIDs
    }

    private static func optimizedCoordinates(_ data: Data?) -> [StoredCoordinate]? {
        guard let data,
              let coordinates = try? JSONDecoder().decode([StoredCoordinate].self, from: data) else {
            return nil
        }
        return coordinates.contains { $0.isOptimized == true } ? coordinates : nil
    }

    private func log(_ error: Error, message: String) {
        let nsError = error as NSError
        logger.error("\(message, privacy: .public) [\(nsError.domain, privacy: .public):\(nsError.code)]")
    }

    private enum RecoveryOutcome {
        case repaired
        case skipped
        case failed
    }
}

struct RouteRecoveryReport: Equatable {
    var inspectedCount: Int = 0
    var repairedCount: Int = 0
    var skippedCount: Int = 0
    var failedCount: Int = 0
}
