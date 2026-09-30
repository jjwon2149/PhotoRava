import Foundation
import SwiftData
import Combine

struct PhotoRecordDraft: Sendable {
    var id: UUID
    var imageData: Data?
    var capturedAt: Date
    var roadName: String?
    var latitude: Double?
    var longitude: Double?
    var ocrConfidence: Float
    var rawOCRText: String?
    var topOCRCandidates: [String]
    var aiQuery: String?
    var aiConfidence: Double?
    var aiReason: String?
    var aiAlternatives: [String]

    @MainActor
    init(record: PhotoRecord) {
        id = record.id
        imageData = record.imageData
        capturedAt = record.capturedAt
        roadName = record.roadName
        latitude = record.latitude
        longitude = record.longitude
        ocrConfidence = record.ocrConfidence
        rawOCRText = record.rawOCRText
        topOCRCandidates = record.topOCRCandidates
        aiQuery = record.aiQuery
        aiConfidence = record.aiConfidence
        aiReason = record.aiReason
        aiAlternatives = record.aiAlternatives
    }

    @MainActor
    func makeModel() -> PhotoRecord {
        let record = PhotoRecord(capturedAt: capturedAt)
        record.id = id
        record.imageData = imageData
        record.roadName = roadName
        record.latitude = latitude
        record.longitude = longitude
        record.ocrConfidence = ocrConfidence
        record.rawOCRText = rawOCRText
        record.topOCRCandidates = topOCRCandidates
        record.aiQuery = aiQuery
        record.aiConfidence = aiConfidence
        record.aiReason = aiReason
        record.aiAlternatives = aiAlternatives
        return record
    }
}

struct RouteAnalysisDraft: Sendable {
    var id: UUID
    var name: String
    var date: Date
    var photoRecords: [PhotoRecordDraft]
    var totalDistance: Double
    var duration: TimeInterval
    var roadNames: [String]
    var aiSummaryCaption: String?
    var aiSummaryDiary: String?
    var aiSummaryHighlights: [String]
    var aiSummaryToneRawValue: String?
    var aiSummaryConfidence: Double?
    var aiSummaryGeneratedAt: Date?
    var userEditedTitle: String?
    var userEditedCaption: String?
    var userEditedDiaryEntry: String?
    var userEditedHighlights: [String]
    var coordinatesData: Data?

    @MainActor
    init(route: Route) {
        id = route.id
        name = route.name
        date = route.date
        photoRecords = route.photoRecords.map(PhotoRecordDraft.init(record:))
        totalDistance = route.totalDistance
        duration = route.duration
        roadNames = route.roadNames
        aiSummaryCaption = route.aiSummaryCaption
        aiSummaryDiary = route.aiSummaryDiary
        aiSummaryHighlights = route.aiSummaryHighlights
        aiSummaryToneRawValue = route.aiSummaryToneRawValue
        aiSummaryConfidence = route.aiSummaryConfidence
        aiSummaryGeneratedAt = route.aiSummaryGeneratedAt
        userEditedTitle = route.userEditedTitle
        userEditedCaption = route.userEditedCaption
        userEditedDiaryEntry = route.userEditedDiaryEntry
        userEditedHighlights = route.userEditedHighlights
        coordinatesData = route.coordinatesData
    }

    @MainActor
    func makeModel() -> Route {
        let route = Route(name: name, date: date)
        route.id = id
        route.photoRecords = photoRecords.map { $0.makeModel() }
        route.totalDistance = totalDistance
        route.duration = duration
        route.roadNames = roadNames
        route.aiSummaryCaption = aiSummaryCaption
        route.aiSummaryDiary = aiSummaryDiary
        route.aiSummaryHighlights = aiSummaryHighlights
        route.aiSummaryToneRawValue = aiSummaryToneRawValue
        route.aiSummaryConfidence = aiSummaryConfidence
        route.aiSummaryGeneratedAt = aiSummaryGeneratedAt
        route.userEditedTitle = userEditedTitle
        route.userEditedCaption = userEditedCaption
        route.userEditedDiaryEntry = userEditedDiaryEntry
        route.userEditedHighlights = userEditedHighlights
        route.coordinatesData = coordinatesData
        return route
    }

    @MainActor
    func apply(to route: Route, in context: ModelContext) throws {
        guard Set(photoRecords.map(\.id)).count == photoRecords.count else {
            throw RouteMutationPersistenceError.committedMutationUnavailable
        }
        let survivingRecords: [(PhotoRecordDraft, PhotoRecord)] = try photoRecords.map { draft in
            let recordID = draft.id
            let descriptor = FetchDescriptor<PhotoRecord>(
                predicate: #Predicate { $0.id == recordID }
            )
            let fetchedRecords: [PhotoRecord]
            do {
                fetchedRecords = try context.fetch(descriptor)
            } catch {
                throw RouteMutationPersistenceError.committedMutationUnavailable
            }
            guard let record = fetchedRecords.first else {
                throw RouteMutationPersistenceError.committedMutationUnavailable
            }
            return (draft, record)
        }

        route.name = name
        route.date = date
        route.totalDistance = totalDistance
        route.duration = duration
        route.roadNames = roadNames
        route.aiSummaryCaption = aiSummaryCaption
        route.aiSummaryDiary = aiSummaryDiary
        route.aiSummaryHighlights = aiSummaryHighlights
        route.aiSummaryToneRawValue = aiSummaryToneRawValue
        route.aiSummaryConfidence = aiSummaryConfidence
        route.aiSummaryGeneratedAt = aiSummaryGeneratedAt
        route.userEditedTitle = userEditedTitle
        route.userEditedCaption = userEditedCaption
        route.userEditedDiaryEntry = userEditedDiaryEntry
        route.userEditedHighlights = userEditedHighlights
        route.coordinatesData = coordinatesData

        route.photoRecords = survivingRecords.map { draft, record in
            record.imageData = draft.imageData
            record.capturedAt = draft.capturedAt
            record.roadName = draft.roadName
            record.latitude = draft.latitude
            record.longitude = draft.longitude
            record.ocrConfidence = draft.ocrConfidence
            record.rawOCRText = draft.rawOCRText
            record.topOCRCandidates = draft.topOCRCandidates
            record.aiQuery = draft.aiQuery
            record.aiConfidence = draft.aiConfidence
            record.aiReason = draft.aiReason
            record.aiAlternatives = draft.aiAlternatives
            return record
        }
    }
}

enum RouteMutationPersistenceError: LocalizedError {
    case routeUnavailable
    case committedMutationUnavailable

    var errorDescription: String? {
        switch self {
        case .routeUnavailable:
            return "변경할 경로를 불러오지 못했습니다."
        case .committedMutationUnavailable:
            return "변경사항은 저장되었지만 바로 표시하지 못했습니다. 경로를 다시 열어 주세요."
        }
    }
}

@MainActor
enum RouteMutationPersistence {
    static func delete(
        container: ModelContainer,
        routeID: UUID,
        contextFactory: (@MainActor () -> ModelContext)? = nil,
        saveContext: @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let context = contextFactory?() ?? ModelContext(container)
        context.autosaveEnabled = false
        let descriptor = FetchDescriptor<Route>(predicate: #Predicate { $0.id == routeID })
        guard let route = try context.fetch(descriptor).first else {
            throw RouteMutationPersistenceError.routeUnavailable
        }
        context.delete(route)
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func commit(
        container: ModelContainer,
        routeID: UUID,
        contextFactory: (@MainActor () -> ModelContext)? = nil,
        recalculate: @MainActor (Route) async throws -> Void = {
            try await RouteReconstructionService.shared.recalculateRouteData(for: $0)
        },
        saveContext: @MainActor (ModelContext) throws -> Void = { try $0.save() },
        mutation: (Route, ModelContext) -> Void
    ) async throws -> RouteAnalysisDraft {
        let context = contextFactory?() ?? ModelContext(container)
        context.autosaveEnabled = false
        let descriptor = FetchDescriptor<Route>(predicate: #Predicate { $0.id == routeID })
        guard let route = try context.fetch(descriptor).first else {
            throw RouteMutationPersistenceError.routeUnavailable
        }

        mutation(route, context)

        do {
            try await recalculate(route)
            try Task.checkCancellation()
            try saveContext(context)
            return RouteAnalysisDraft(route: route)
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
protocol RouteAnalysisPersisting {
    func persist(_ draft: RouteAnalysisDraft) throws -> Route
}

@MainActor
final class SwiftDataRouteAnalysisPersistence: RouteAnalysisPersisting {
    private let resultContext: ModelContext
    private let contextFactory: @MainActor () -> ModelContext
    private let saveContext: @MainActor (ModelContext) throws -> Void

    init(
        resultContext: ModelContext,
        contextFactory: (@MainActor () -> ModelContext)? = nil,
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.resultContext = resultContext
        self.contextFactory = contextFactory ?? { ModelContext(resultContext.container) }
        self.saveContext = saveContext
    }

    func persist(_ draft: RouteAnalysisDraft) throws -> Route {
        let context = contextFactory()
        context.autosaveEnabled = false
        let routeID = draft.id
        let descriptor = FetchDescriptor<Route>(
            predicate: #Predicate { $0.id == routeID }
        )

        if let existing = try context.fetch(descriptor).first {
            if let result = resultContext.model(for: existing.persistentModelID) as? Route {
                return result
            }
            throw RouteAnalysisPersistenceError.committedRouteUnavailable
        }

        let route = draft.makeModel()
        context.insert(route)

        do {
            try saveContext(context)
            if let result = resultContext.model(for: route.persistentModelID) as? Route {
                return result
            }
            throw RouteAnalysisPersistenceError.committedRouteUnavailable
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum RouteAnalysisPersistenceError: LocalizedError {
    case committedRouteUnavailable

    var errorDescription: String? {
        "경로는 저장되었지만 바로 표시하지 못했습니다. 경로 목록에서 다시 열어 주세요."
    }
}

@MainActor
final class RouteAnalysisCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case saving
        case failed(canRetrySave: Bool)
        case completed
        case cancelled
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var completedRoute: Route?
    private(set) var failure: Error?

    private let persistence: any RouteAnalysisPersisting
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var pendingDraft: RouteAnalysisDraft?

    init(persistence: any RouteAnalysisPersisting) {
        self.persistence = persistence
    }

    func start(
        operation: @escaping @MainActor () async throws -> RouteAnalysisDraft,
        onFailure: @escaping @MainActor (Error, Bool) -> Void = { _, _ in },
        onCompletion: @escaping @MainActor (Route) -> Void = { _ in }
    ) {
        cancelCurrentTask(markCancelled: false)
        let runID = UUID()
        generation = runID
        pendingDraft = nil
        completedRoute = nil
        failure = nil
        phase = .running

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let draft = try await operation()
                try Task.checkCancellation()
                guard generation == runID else { return }
                pendingDraft = draft
                try persistPendingDraft(runID: runID, onFailure: onFailure, onCompletion: onCompletion)
            } catch is CancellationError {
                guard generation == runID else { return }
                phase = .cancelled
            } catch {
                guard generation == runID else { return }
                if case .failed = phase {
                    return
                }
                failure = error
                phase = .failed(canRetrySave: false)
                onFailure(error, false)
            }
        }
    }

    func retryPersistence(
        onFailure: @escaping @MainActor (Error, Bool) -> Void = { _, _ in },
        onCompletion: @escaping @MainActor (Route) -> Void = { _ in }
    ) {
        guard pendingDraft != nil else { return }
        let runID = generation
        do {
            try persistPendingDraft(runID: runID, onFailure: onFailure, onCompletion: onCompletion)
        } catch {
            // persistPendingDraft publishes the recoverable error.
        }
    }

    func cancel() {
        cancelCurrentTask(markCancelled: completedRoute == nil)
    }

    private func persistPendingDraft(
        runID: UUID,
        onFailure: @MainActor (Error, Bool) -> Void,
        onCompletion: @MainActor (Route) -> Void
    ) throws {
        try Task.checkCancellation()
        guard generation == runID, let pendingDraft else { throw CancellationError() }
        phase = .saving

        do {
            let route = try persistence.persist(pendingDraft)
            guard generation == runID else { return }
            self.pendingDraft = nil
            completedRoute = route
            failure = nil
            phase = .completed
            onCompletion(route)
        } catch {
            failure = error
            let canRetry = !(error is RouteAnalysisPersistenceError)
            if !canRetry { self.pendingDraft = nil }
            phase = .failed(canRetrySave: canRetry)
            onFailure(error, canRetry)
            throw error
        }
    }

    private func cancelCurrentTask(markCancelled: Bool) {
        task?.cancel()
        task = nil
        generation = UUID()
        if markCancelled {
            pendingDraft = nil
            phase = .cancelled
        }
    }
}
