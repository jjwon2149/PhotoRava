import CoreLocation
import XCTest
@testable import PhotoRava

final class RouteGeometryCalculatorTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    func testRoundTripPreservesMiddleCoordinateAndCountsBothLegs() {
        let a = coordinate(latitude: 37.5665, longitude: 126.9780)
        let b = coordinate(latitude: 37.5700, longitude: 126.9920)
        let result = RouteGeometryCalculator.calculate(from: [
            input(at: 0, coordinate: a),
            input(at: 60, coordinate: b),
            input(at: 120, coordinate: a)
        ])

        XCTAssertEqual(result.coordinates.count, 3)
        assertCoordinate(result.coordinates[1], equals: b)

        let oneWayKilometers = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1_000
        XCTAssertEqual(result.distanceKilometers, oneWayKilometers * 2, accuracy: 0.001)
        XCTAssertEqual(result.duration, 120)
    }

    func testNormalRouteSortsByCaptureDateAndUsesSameCoordinatesForDistance() {
        let a = coordinate(latitude: 37.50, longitude: 127.00)
        let b = coordinate(latitude: 37.51, longitude: 127.01)
        let c = coordinate(latitude: 37.52, longitude: 127.03)
        let result = RouteGeometryCalculator.calculate(from: [
            input(at: 120, coordinate: c, roadName: " C road "),
            input(at: 0, coordinate: a, roadName: "A road"),
            input(at: 60, coordinate: b, roadName: "B road")
        ])

        XCTAssertEqual(result.coordinates.count, 3)
        assertCoordinate(result.coordinates[0], equals: a)
        assertCoordinate(result.coordinates[1], equals: b)
        assertCoordinate(result.coordinates[2], equals: c)

        let expected = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            + CLLocation(latitude: b.latitude, longitude: b.longitude)
                .distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
        XCTAssertEqual(result.distanceKilometers, expected / 1_000, accuracy: 0.001)
        XCTAssertEqual(result.roadNames, ["A road", "B road", "C road"])
    }

    func testDuplicateCoordinatesContributeZeroDistanceWithoutBeingRemoved() {
        let a = coordinate(latitude: 35.1796, longitude: 129.0756)
        let b = coordinate(latitude: 35.1805, longitude: 129.0800)
        let result = RouteGeometryCalculator.calculate(from: [
            input(at: 0, coordinate: a),
            input(at: 30, coordinate: a),
            input(at: 60, coordinate: b)
        ])

        XCTAssertEqual(result.coordinates.count, 3)
        assertCoordinate(result.coordinates[0], equals: a)
        assertCoordinate(result.coordinates[1], equals: a)
        let expected = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1_000
        XCTAssertEqual(result.distanceKilometers, expected, accuracy: 0.001)
    }

    func testEmptyAndSingleCoordinateHaveZeroDistance() {
        let empty = RouteGeometryCalculator.calculate(from: [])
        XCTAssertTrue(empty.coordinates.isEmpty)
        XCTAssertEqual(empty.distanceKilometers, 0)
        XCTAssertEqual(empty.duration, 0)

        let only = coordinate(latitude: 33.4996, longitude: 126.5312)
        let single = RouteGeometryCalculator.calculate(from: [input(at: 0, coordinate: only)])
        XCTAssertEqual(single.coordinates.count, 1)
        assertCoordinate(single.coordinates[0], equals: only)
        XCTAssertEqual(single.distanceKilometers, 0)
        XCTAssertEqual(single.duration, 0)
    }

    func testMissingAndInvalidGPSAreExcludedWhileFallbackRoadNameIsRetained() {
        let valid = coordinate(latitude: 37.0, longitude: 127.0)
        let result = RouteGeometryCalculator.calculate(from: [
            RouteGeometryInput(
                capturedAt: origin,
                latitude: nil,
                longitude: nil,
                roadName: nil,
                fallbackRoadName: " OCR road "
            ),
            RouteGeometryInput(
                capturedAt: origin.addingTimeInterval(30),
                latitude: 91,
                longitude: 127,
                roadName: nil,
                fallbackRoadName: nil
            ),
            input(at: 60, coordinate: valid)
        ])

        XCTAssertEqual(result.coordinates.count, 1)
        assertCoordinate(result.coordinates[0], equals: valid)
        XCTAssertEqual(result.distanceKilometers, 0)
        XCTAssertEqual(result.roadNames, ["OCR road"])
    }

    func testSummaryDistanceMatchingRejectsStaleDistanceAndAcceptsDisplayedRounding() {
        XCTAssertTrue(
            RouteGeometryCalculator.summaryDistanceMatches(
                "약 1.0km를 이동한 기록입니다.",
                distanceKilometers: 1.04
            )
        )
        XCTAssertFalse(
            RouteGeometryCalculator.summaryDistanceMatches(
                "약 1.0km를 이동한 기록입니다.",
                distanceKilometers: 11.0
            )
        )
    }

    private func input(
        at offset: TimeInterval,
        coordinate: CLLocationCoordinate2D,
        roadName: String? = nil
    ) -> RouteGeometryInput {
        RouteGeometryInput(
            capturedAt: origin.addingTimeInterval(offset),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            roadName: roadName,
            fallbackRoadName: nil
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func assertCoordinate(
        _ actual: StoredCoordinate,
        equals expected: CLLocationCoordinate2D,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.latitude, expected.latitude, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(actual.longitude, expected.longitude, accuracy: 0.000_001, file: file, line: line)
    }
}
