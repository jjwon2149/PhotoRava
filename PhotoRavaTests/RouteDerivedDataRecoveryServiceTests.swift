import Foundation
import CoreLocation
import SwiftData
import XCTest
@testable import PhotoRava

@MainActor
final class RouteDerivedDataRecoveryServiceTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testRecoveryRebuildsDerivedGeometryAndPreservesStoredContentAcrossReopen() async throws {
        let storeURL = try makeSeededStore()

        do {
            let container = try makeContainer(at: storeURL)
            let report = try await RouteDerivedDataRecoveryService().recoverOptimizedRoutes(in: container)
            XCTAssertEqual(
                report,
                RouteRecoveryReport(inspectedCount: 1, repairedCount: 1, skippedCount: 0, failedCount: 0)
            )
        }

        let reopened = try makeContainer(at: storeURL)
        let routes = try ModelContext(reopened).fetch(FetchDescriptor<Route>())
        XCTAssertEqual(routes.count, 2)

        let repaired = try XCTUnwrap(routes.first { $0.name == "왕복 여행" })
        XCTAssertEqual(repaired.photoRecords.count, 3)
        XCTAssertEqual(repaired.userEditedTitle, "사용자 제목")
        XCTAssertEqual(repaired.userEditedCaption, "사용자 캡션")
        XCTAssertEqual(repaired.userEditedDiaryEntry, "사용자 일기")
        XCTAssertEqual(repaired.userEditedHighlights, ["사용자 하이라이트"])
        XCTAssertEqual(repaired.aiSummaryCaption, "기존 자동 요약")

        let coordinates = try XCTUnwrap(
            try JSONDecoder().decode([StoredCoordinate].self, from: XCTUnwrap(repaired.coordinatesData))
        )
        XCTAssertEqual(coordinates.count, 3)
        XCTAssertEqual(coordinates[1].latitude, 37.5700, accuracy: 0.000_001)
        XCTAssertFalse(coordinates.contains { $0.isOptimized == true })

        let oneWay = CLLocationDistance.fixtureDistance(
            fromLatitude: 37.5665,
            fromLongitude: 126.9780,
            toLatitude: 37.5700,
            toLongitude: 126.9920
        )
        XCTAssertEqual(repaired.totalDistance, oneWay * 2, accuracy: 0.001)

        let untouched = try XCTUnwrap(routes.first { $0.name == "미보정 여행" })
        XCTAssertEqual(untouched.totalDistance, 42)
    }

    func testFailedRecoveryRollsBackThenRetryPersistsExactlyOnceAndIsIdempotent() async throws {
        let storeURL = try makeSeededStore()

        do {
            let container = try makeContainer(at: storeURL)
            let service = RouteDerivedDataRecoveryService(saveContext: { _ in
                throw InjectedSaveError()
            })
            let report = try await service.recoverOptimizedRoutes(in: container)
            XCTAssertEqual(report.failedCount, 1)
            XCTAssertEqual(report.repairedCount, 0)
        }

        do {
            let reopenedAfterFailure = try makeContainer(at: storeURL)
            let routes = try ModelContext(reopenedAfterFailure).fetch(FetchDescriptor<Route>())
            let failedRoute = try XCTUnwrap(routes.first { $0.name == "왕복 여행" })
            XCTAssertEqual(failedRoute.totalDistance, 999)
            XCTAssertTrue(try decodedCoordinates(of: failedRoute).contains { $0.isOptimized == true })

            let retry = try await RouteDerivedDataRecoveryService().recoverOptimizedRoutes(in: reopenedAfterFailure)
            XCTAssertEqual(retry.repairedCount, 1)
            XCTAssertEqual(retry.failedCount, 0)
        }

        do {
            let reopenedAfterRetry = try makeContainer(at: storeURL)
            let routes = try ModelContext(reopenedAfterRetry).fetch(FetchDescriptor<Route>())
            XCTAssertEqual(routes.count, 2)
            let repairedRoute = try XCTUnwrap(routes.first { $0.name == "왕복 여행" })
            XCTAssertFalse(try decodedCoordinates(of: repairedRoute).contains { $0.isOptimized == true })

            let repeated = try await RouteDerivedDataRecoveryService().recoverOptimizedRoutes(in: reopenedAfterRetry)
            XCTAssertEqual(
                repeated,
                RouteRecoveryReport(inspectedCount: 0, repairedCount: 0, skippedCount: 0, failedCount: 0)
            )
            XCTAssertEqual(try ModelContext(reopenedAfterRetry).fetchCount(FetchDescriptor<Route>()), 2)
        }
    }

    func testRecoveryWithoutOriginalCoordinatesLeavesDerivedDataUntouched() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRavaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let storeURL = directory.appendingPathComponent("missing-originals.store")
        let oldCoordinates = try JSONEncoder().encode([
            StoredCoordinate(latitude: 37.1, longitude: 127.1, isOptimized: true)
        ])

        do {
            let container = try makeContainer(at: storeURL)
            let context = ModelContext(container)
            let route = Route(name: "원본 좌표 없음", date: Date())
            route.totalDistance = 77
            route.coordinatesData = oldCoordinates
            route.photoRecords = [PhotoRecord(capturedAt: Date())]
            context.insert(route)
            try context.save()

            let report = try await RouteDerivedDataRecoveryService().recoverOptimizedRoutes(in: container)
            XCTAssertEqual(
                report,
                RouteRecoveryReport(inspectedCount: 1, repairedCount: 0, skippedCount: 1, failedCount: 0)
            )
        }

        let reopened = try makeContainer(at: storeURL)
        let routes = try ModelContext(reopened).fetch(FetchDescriptor<Route>())
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes[0].totalDistance, 77)
        XCTAssertEqual(routes[0].coordinatesData, oldCoordinates)
    }

    private func makeSeededStore() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRavaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let storeURL = directory.appendingPathComponent("routes.store")

        let container = try makeContainer(at: storeURL)
        let context = ModelContext(container)

        let route = Route(name: "왕복 여행", date: Date(timeIntervalSince1970: 1_700_000_000))
        route.totalDistance = 999
        route.duration = 999
        route.roadNames = ["오래된 도로"]
        route.aiSummaryCaption = "기존 자동 요약"
        route.userEditedTitle = "사용자 제목"
        route.userEditedCaption = "사용자 캡션"
        route.userEditedDiaryEntry = "사용자 일기"
        route.userEditedHighlights = ["사용자 하이라이트"]
        route.coordinatesData = try JSONEncoder().encode([
            StoredCoordinate(latitude: 37.5665, longitude: 126.9780, isOptimized: false),
            StoredCoordinate(latitude: 37.5665, longitude: 126.9780, isOptimized: true),
            StoredCoordinate(latitude: 37.5665, longitude: 126.9780, isOptimized: false)
        ])
        route.photoRecords = [
            record(at: 120, latitude: 37.5665, longitude: 126.9780, roadName: "A"),
            record(at: 0, latitude: 37.5665, longitude: 126.9780, roadName: "A"),
            record(at: 60, latitude: 37.5700, longitude: 126.9920, roadName: "B")
        ]
        context.insert(route)

        let untouched = Route(name: "미보정 여행", date: Date(timeIntervalSince1970: 1_600_000_000))
        untouched.totalDistance = 42
        untouched.coordinatesData = try JSONEncoder().encode([
            StoredCoordinate(latitude: 35, longitude: 129, isOptimized: false)
        ])
        context.insert(untouched)
        try context.save()
        return storeURL
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(for: Route.self, PhotoRecord.self, configurations: configuration)
    }

    private func record(
        at offset: TimeInterval,
        latitude: Double,
        longitude: Double,
        roadName: String
    ) -> PhotoRecord {
        let record = PhotoRecord(capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + offset))
        record.latitude = latitude
        record.longitude = longitude
        record.roadName = roadName
        return record
    }

    private func decodedCoordinates(of route: Route) throws -> [StoredCoordinate] {
        try JSONDecoder().decode([StoredCoordinate].self, from: XCTUnwrap(route.coordinatesData))
    }
}

private struct InjectedSaveError: Error {}

private enum CLLocationDistance {
    static func fixtureDistance(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let start = CLLocation(latitude: fromLatitude, longitude: fromLongitude)
        let end = CLLocation(latitude: toLatitude, longitude: toLongitude)
        return start.distance(from: end) / 1_000
    }
}
