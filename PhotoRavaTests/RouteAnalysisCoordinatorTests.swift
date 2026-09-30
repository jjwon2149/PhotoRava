import Combine
import Foundation
import SwiftData
import XCTest
@testable import PhotoRava

@MainActor
final class RouteAnalysisCoordinatorTests: XCTestCase {
    private var temporaryDirectories: [URL] = []
    private var cancellables: Set<AnyCancellable> = []

    override func tearDownWithError() throws {
        cancellables.removeAll()
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testCancellationWhileOperationIsSuspendedNeverPersists() async throws {
        let persistence = CountingPersistence()
        let coordinator = RouteAnalysisCoordinator(persistence: persistence)
        let reached = expectation(description: "operation reached suspension gate")
        let cancelled = phaseExpectation(.cancelled, from: coordinator)
        let gate = CancellationGate(reached: reached)

        coordinator.start {
            try await gate.wait()
            return self.makeDraft(name: "취소된 실행")
        }

        await fulfillment(of: [reached], timeout: 1)
        coordinator.cancel()
        await fulfillment(of: [cancelled], timeout: 1)

        XCTAssertEqual(coordinator.phase, .cancelled)
        XCTAssertNil(coordinator.completedRoute)
        XCTAssertEqual(persistence.attemptCount, 0)
    }

    func testSaveFailureIsReportedOnceAndRetryPersistsOneRouteAcrossReopen() async throws {
        let storeURL = try makeStoreURL()
        var failureCallbackCount = 0

        do {
            let container = try makeContainer(at: storeURL)
            let resultContext = ModelContext(container)
            var saveAttemptCount = 0
            let persistence = SwiftDataRouteAnalysisPersistence(
                resultContext: resultContext,
                saveContext: { context in
                    saveAttemptCount += 1
                    if saveAttemptCount == 1 {
                        throw InjectedPersistenceError()
                    }
                    try context.save()
                }
            )
            let coordinator = RouteAnalysisCoordinator(persistence: persistence)
            let failed = phaseExpectation(.failed(canRetrySave: true), from: coordinator)

            coordinator.start(
                operation: { self.makeDraft(name: "재시도 경로") },
                onFailure: { _, canRetry in
                    failureCallbackCount += 1
                    XCTAssertTrue(canRetry)
                }
            )
            await fulfillment(of: [failed], timeout: 1)

            XCTAssertEqual(failureCallbackCount, 1)
            XCTAssertEqual(saveAttemptCount, 1)
            XCTAssertNil(coordinator.completedRoute)
            XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Route>()), 0)

            let completed = phaseExpectation(.completed, from: coordinator)
            coordinator.retryPersistence()
            await fulfillment(of: [completed], timeout: 1)

            XCTAssertEqual(saveAttemptCount, 2)
            XCTAssertEqual(failureCallbackCount, 1)
            XCTAssertEqual(coordinator.completedRoute?.name, "재시도 경로")
            XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Route>()), 1)
        }

        let reopened = try makeContainer(at: storeURL)
        let storedRoutes = try ModelContext(reopened).fetch(FetchDescriptor<Route>())
        XCTAssertEqual(storedRoutes.count, 1)
        XCTAssertEqual(storedRoutes.first?.name, "재시도 경로")
    }

    func testLateResponseFromCancelledRunCannotReplaceRetryResult() async throws {
        let persistence = CountingPersistence()
        let coordinator = RouteAnalysisCoordinator(persistence: persistence)
        let firstReached = expectation(description: "first run reached late response gate")
        let firstReturned = expectation(description: "first late response returned")
        let gate = LateResponseGate(reached: firstReached)

        coordinator.start {
            await gate.wait()
            firstReturned.fulfill()
            return self.makeDraft(name: "이전 실행")
        }
        await fulfillment(of: [firstReached], timeout: 1)

        let completed = phaseExpectation(.completed, from: coordinator)
        coordinator.start {
            self.makeDraft(name: "새 실행")
        }
        await fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(coordinator.completedRoute?.name, "새 실행")
        XCTAssertEqual(persistence.persistedNames, ["새 실행"])

        gate.resume()
        await fulfillment(of: [firstReturned], timeout: 1)

        XCTAssertEqual(coordinator.phase, .completed)
        XCTAssertEqual(coordinator.completedRoute?.name, "새 실행")
        XCTAssertEqual(persistence.persistedNames, ["새 실행"])
    }

    func testCloseAfterCompletionDoesNotTurnSavedResultIntoCancellation() async throws {
        let persistence = CountingPersistence()
        let coordinator = RouteAnalysisCoordinator(persistence: persistence)
        let completed = phaseExpectation(.completed, from: coordinator)

        coordinator.start {
            self.makeDraft(name: "저장 완료")
        }
        await fulfillment(of: [completed], timeout: 1)
        coordinator.cancel()

        XCTAssertEqual(coordinator.phase, .completed)
        XCTAssertEqual(coordinator.completedRoute?.name, "저장 완료")
        XCTAssertEqual(persistence.attemptCount, 1)
    }

    func testProductionPersistenceTreatsRepeatedDraftUUIDAsOneRoute() throws {
        let storeURL = try makeStoreURL()
        let container = try makeContainer(at: storeURL)
        let persistence = SwiftDataRouteAnalysisPersistence(resultContext: ModelContext(container))
        let draft = makeDraft(name: "동일 초안")

        _ = try persistence.persist(draft)
        _ = try persistence.persist(draft)

        let context = ModelContext(container)
        let routes = try context.fetch(FetchDescriptor<Route>())
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes.first?.id, draft.id)
        XCTAssertEqual(routes.first?.name, "동일 초안")
    }

    func testRouteMutationFailureRollsBackAndSuccessfulRetryPreservesIdentityAndSummary() async throws {
        let storeURL = try makeStoreURL()
        let identifiers = try seedMutationStore(at: storeURL)

        do {
            let container = try makeContainer(at: storeURL)
            do {
                _ = try await RouteMutationPersistence.commit(
                    container: container,
                    routeID: identifiers.routeID,
                    recalculate: { route in route.totalDistance = 999 },
                    saveContext: { _ in throw InjectedPersistenceError() },
                    mutation: { route, _ in
                        route.name = "저장되면 안 되는 이름"
                        route.photoRecords.removeAll()
                    }
                )
                XCTFail("Injected save failure should be propagated")
            } catch is InjectedPersistenceError {
                // Expected.
            }
        }

        do {
            let reopenedAfterFailure = try makeContainer(at: storeURL)
            let route = try XCTUnwrap(
                try ModelContext(reopenedAfterFailure).fetch(FetchDescriptor<Route>()).first
            )
            XCTAssertEqual(route.name, "원래 이름")
            XCTAssertEqual(route.totalDistance, 1)
            XCTAssertEqual(route.photoRecords.map(\.id), [identifiers.photoID])
            XCTAssertEqual(route.userEditedTitle, "사용자 제목")
        }

        do {
            let container = try makeContainer(at: storeURL)
            let draft = try await RouteMutationPersistence.commit(
                container: container,
                routeID: identifiers.routeID,
                recalculate: { route in route.totalDistance = 2.5 },
                mutation: { route, _ in route.name = "저장된 이름" }
            )
            XCTAssertEqual(draft.id, identifiers.routeID)
            XCTAssertEqual(draft.photoRecords.map(\.id), [identifiers.photoID])
            XCTAssertEqual(draft.userEditedTitle, "사용자 제목")
        }

        let reopenedAfterSuccess = try makeContainer(at: storeURL)
        let routes = try ModelContext(reopenedAfterSuccess).fetch(FetchDescriptor<Route>())
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes[0].name, "저장된 이름")
        XCTAssertEqual(routes[0].totalDistance, 2.5)
        XCTAssertEqual(routes[0].photoRecords.map(\.id), [identifiers.photoID])
        XCTAssertEqual(routes[0].userEditedTitle, "사용자 제목")
    }

    func testApplyingDeletionDraftDoesNotResurrectRemovedPhotoAcrossReopen() async throws {
        let storeURL = try makeStoreURL()
        let container = try makeContainer(at: storeURL)
        let seedContext = ModelContext(container)
        let route = Route(name: "사진 삭제 경로", date: Date(timeIntervalSince1970: 1_700_000_000))
        let deletedPhoto = PhotoRecord(capturedAt: route.date)
        deletedPhoto.latitude = 37.5
        deletedPhoto.longitude = 127.0
        let survivingPhoto = PhotoRecord(capturedAt: route.date.addingTimeInterval(60))
        survivingPhoto.latitude = 37.6
        survivingPhoto.longitude = 127.1
        route.photoRecords = [deletedPhoto, survivingPhoto]
        seedContext.insert(route)
        try seedContext.save()

        let routeID = route.id
        let deletedID = deletedPhoto.id
        let survivingID = survivingPhoto.id
        let resultContext = ModelContext(container)
        let resultRoute = try XCTUnwrap(
            try resultContext.fetch(
                FetchDescriptor<Route>(predicate: #Predicate { $0.id == routeID })
            ).first
        )
        XCTAssertEqual(resultRoute.photoRecords.count, 2)

        let savedDraft = try await RouteMutationPersistence.commit(
            container: container,
            routeID: routeID,
            recalculate: { mutatedRoute in
                let survivor = try XCTUnwrap(mutatedRoute.photoRecords.first)
                mutatedRoute.totalDistance = 0
                mutatedRoute.coordinatesData = try JSONEncoder().encode([
                    StoredCoordinate(
                        latitude: try XCTUnwrap(survivor.latitude),
                        longitude: try XCTUnwrap(survivor.longitude)
                    )
                ])
            },
            mutation: { mutatedRoute, context in
                let removed = mutatedRoute.photoRecords.first { $0.id == deletedID }
                mutatedRoute.photoRecords = mutatedRoute.photoRecords.filter { $0.id == survivingID }
                if let removed {
                    context.delete(removed)
                }
            }
        )

        XCTAssertEqual(savedDraft.photoRecords.map(\.id), [survivingID])
        try savedDraft.apply(to: resultRoute, in: resultContext)
        try resultContext.save()
        XCTAssertEqual(resultRoute.photoRecords.map(\.id), [survivingID])

        let reopened = try makeContainer(at: storeURL)
        let verificationContext = ModelContext(reopened)
        let reopenedRoutes = try verificationContext.fetch(FetchDescriptor<Route>())
        let reopenedPhotos = try verificationContext.fetch(FetchDescriptor<PhotoRecord>())
        XCTAssertEqual(reopenedRoutes.count, 1)
        XCTAssertEqual(reopenedRoutes[0].photoRecords.map(\.id), [survivingID])
        XCTAssertEqual(reopenedPhotos.map(\.id), [survivingID])
        XCTAssertFalse(reopenedPhotos.contains { $0.id == deletedID })
        XCTAssertEqual(reopenedRoutes[0].totalDistance, 0)
        XCTAssertEqual(try decodedCoordinateCount(of: reopenedRoutes[0]), 1)
    }

    func testApplyingDraftWithMissingSurvivorThrowsWithoutPartialMutation() throws {
        let storeURL = try makeStoreURL()
        let container = try makeContainer(at: storeURL)
        let context = ModelContext(container)
        let route = Route(name: "원래 이름", date: Date(timeIntervalSince1970: 1_700_000_000))
        let first = PhotoRecord(capturedAt: route.date)
        let second = PhotoRecord(capturedAt: route.date.addingTimeInterval(60))
        route.photoRecords = [first, second]
        context.insert(route)
        try context.save()

        let originalIDs = route.photoRecords.map(\.id)
        var invalidDraft = RouteAnalysisDraft(route: route)
        invalidDraft.name = "부분 적용되면 안 되는 이름"
        let missing = PhotoRecord(capturedAt: route.date.addingTimeInterval(120))
        invalidDraft.photoRecords.append(PhotoRecordDraft(record: missing))

        XCTAssertThrowsError(try invalidDraft.apply(to: route, in: context))
        XCTAssertEqual(route.name, "원래 이름")
        XCTAssertEqual(route.photoRecords.map(\.id), originalIDs)
    }

    private func phaseExpectation(
        _ expectedPhase: RouteAnalysisCoordinator.Phase,
        from coordinator: RouteAnalysisCoordinator
    ) -> XCTestExpectation {
        let result = expectation(description: "phase becomes \(expectedPhase)")
        coordinator.$phase
            .filter { $0 == expectedPhase }
            .prefix(1)
            .sink { _ in result.fulfill() }
            .store(in: &cancellables)
        return result
    }

    private func makeDraft(name: String) -> RouteAnalysisDraft {
        let route = Route(name: name, date: Date(timeIntervalSince1970: 1_700_000_000))
        route.totalDistance = 1.25
        route.duration = 120
        return RouteAnalysisDraft(route: route)
    }

    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRavaCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory.appendingPathComponent("routes.store")
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Route.self,
            PhotoRecord.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    private func seedMutationStore(at url: URL) throws -> (routeID: UUID, photoID: UUID) {
        let container = try makeContainer(at: url)
        let context = ModelContext(container)
        let route = Route(name: "원래 이름", date: Date(timeIntervalSince1970: 1_700_000_000))
        route.totalDistance = 1
        route.userEditedTitle = "사용자 제목"
        let photo = PhotoRecord(capturedAt: route.date)
        photo.latitude = 37.5
        photo.longitude = 127
        route.photoRecords = [photo]
        context.insert(route)
        try context.save()
        return (route.id, photo.id)
    }

    private func decodedCoordinateCount(of route: Route) throws -> Int {
        try JSONDecoder()
            .decode([StoredCoordinate].self, from: XCTUnwrap(route.coordinatesData))
            .count
    }
}

@MainActor
private final class CancellationGate {
    private let reached: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Error>?

    init(reached: XCTestExpectation) {
        self.reached = reached
    }

    func wait() async throws {
        reached.fulfill()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resumeAfterCancellation()
            }
        }
    }

    private func resumeAfterCancellation() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

@MainActor
private final class LateResponseGate {
    private let reached: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(reached: XCTestExpectation) {
        self.reached = reached
    }

    func wait() async {
        reached.fulfill()
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class CountingPersistence: RouteAnalysisPersisting {
    private(set) var attemptCount = 0
    private(set) var persistedNames: [String] = []

    func persist(_ draft: RouteAnalysisDraft) throws -> Route {
        attemptCount += 1
        persistedNames.append(draft.name)
        return draft.makeModel()
    }
}

private struct InjectedPersistenceError: Error {}
