//
//  RouteEditView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData

struct RouteEditView: View {
    @Bindable var route: Route
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteAlert = false
    @State private var isRecalculating = false
    @State private var draftName: String
    @State private var draftRecordIDs: [UUID]
    @State private var draftRoadNames: [UUID: String]
    @State private var saveErrorMessage: String?
    @State private var saveTask: Task<Void, Never>?
    
    // AI 관련 상태
    @State private var isGeneratingAI = false
    @State private var aiGenerationStatus = "AI가 경로를 요약하는 중..."
    @State private var aiCaption: String?
    @State private var aiDiary: String?
    @State private var aiHighlights: [String] = []
    @State private var selectedSummaryTone: RouteSummaryTonePreference = .warm

    init(route: Route) {
        self.route = route
        _draftName = State(initialValue: route.name)
        _draftRecordIDs = State(initialValue: route.photoRecords.map(\.id))
        _draftRoadNames = State(initialValue: Dictionary(
            uniqueKeysWithValues: route.photoRecords.map { ($0.id, $0.roadName ?? "") }
        ))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("경로 이름", text: $draftName)
                            .font(.headline)
                        
                        if visibleAICaption == nil {
                            if isGeneratingAI {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button {
                                    Task { await generateAISummary() }
                                } label: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    if isGeneratingAI {
                        RouteAIActivityPanel(
                            title: "AI 요약 생성 중",
                            message: aiGenerationStatus,
                            showsSkeleton: true
                        )
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // AI 요약 결과 및 감성 일기 미리보기
                    if let caption = visibleAICaption {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("AI의 여행 기록", systemImage: "sparkles")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.purple)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(caption)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                
                                if let diary = aiDiary {
                                    Text(diary)
                                        .font(.system(size: 14, weight: .regular, design: .serif))
                                        .lineSpacing(4)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                }
                                
                                if !aiHighlights.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(aiHighlights.indices, id: \.self) { index in
                                                HStack(spacing: 4) {
                                                    Text(aiHighlights[index])
                                                        .lineLimit(1)

                                                    Button {
                                                        removeAIHighlight(at: index)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 10, weight: .semibold))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityLabel("\(aiHighlights[index]) 하이라이트 삭제")
                                                }
                                                .font(.system(size: 10, weight: .medium))
                                                .padding(.leading, 8)
                                                .padding(.trailing, 6)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.1))
                                                .foregroundStyle(.purple)
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                            
                            HStack {
                                Spacer()
                                RouteSummaryToneMenu(
                                    selection: $selectedSummaryTone,
                                    isDisabled: isGeneratingAI
                                )

                                if isGeneratingAI {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button {
                                        Task { await generateAISummary() }
                                    } label: {
                                        Label("다시 만들기", systemImage: "arrow.clockwise")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.purple)
                                    .controlSize(.mini)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } footer: {
                    if visibleAICaption == nil {
                        Text("✨ 마법봉을 눌러 AI가 제안하는 매력적인 제목과 일기를 만들어보세요.")
                    }
                }
                
                Section("사진 (\(draftRecordIDs.count)개)") {
                    ForEach(draftRecordIDs, id: \.self) { recordID in
                        if let record = route.photoRecords.first(where: { $0.id == recordID }) {
                        HStack(spacing: 12) {
                            // Thumbnail
                            if let imageData = record.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("도로명", text: Binding(
                                    get: { draftRoadNames[recordID] ?? "" },
                                    set: { draftRoadNames[recordID] = $0 }
                                ))
                                .font(.subheadline)
                                
                                Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                    .onMove(perform: moveRecords)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("경로 삭제", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("경로 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        saveTask?.cancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isRecalculating {
                        ProgressView()
                    } else {
                        Button("완료") {
                            saveTask?.cancel()
                            saveTask = Task {
                                await saveChanges()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
            .interactiveDismissDisabled(isRecalculating)
            .onDisappear {
                saveTask?.cancel()
            }
            .alert("경로 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    saveTask?.cancel()
                    saveTask = Task { await deleteRoute() }
                }
            } message: {
                Text("이 경로를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("변경사항 저장 실패", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "변경사항이 저장되지 않았습니다.")
            }
            .task(id: route.id) {
                syncStoredAISummary()
            }
        }
    }

    private var visibleAICaption: String? {
        guard let caption = aiCaption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            return nil
        }

        return caption
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        draftRecordIDs.remove(atOffsets: offsets)
    }
    
    private func moveRecords(from source: IndexSet, to destination: Int) {
        draftRecordIDs.move(fromOffsets: source, toOffset: destination)
    }
    
    @MainActor
    private func generateAISummary() async {
        guard !isGeneratingAI else { return }
        isGeneratingAI = true
        defer { isGeneratingAI = false }
        aiGenerationStatus = "경로 통계를 정리하는 중..."
        
        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)
        
        do {
            withAnimation(.easeInOut(duration: 0.2)) {
                aiGenerationStatus = "AI가 경로를 요약하는 중..."
            }

            if #available(iOS 26.0, *) {
                let summary = try await LocalAIService.shared.routeNarrator(
                    snapshot: snapshot,
                    tonePreference: selectedSummaryTone
                )
                try Task.checkCancellation()
                withAnimation {
                    draftName = summary.title
                    aiCaption = summary.caption
                    aiDiary = summary.diaryEntry
                    aiHighlights = summary.highlights
                }
            } else {
                // 하위 버전 fallback
                aiGenerationStatus = "대체 요약을 구성하는 중..."
                try await Task.sleep(nanoseconds: 800_000_000)
                withAnimation {
                    draftName = "✨ [AI] \(snapshot.startName) 여정"
                    aiCaption = "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동한 \(snapshot.timeOfDay ?? "오전")의 기록"
                    aiDiary = "\(snapshot.timeOfDay ?? "오후")의 햇살이 따뜻했던 날, \(snapshot.startName)에서 여정을 시작했습니다. 발길 닿는 곳마다 펼쳐진 풍경들은 제법 낭만적이었고, \(snapshot.durationMin)분간의 시간은 온전히 저만의 여행이 되었습니다."
                    aiHighlights = ["경로 기록 보완", "감성 요약 생성", "이동 흐름 정리"]
                }
            }
        } catch {
            if error is CancellationError || Task.isCancelled { return }
            print("AI summary generation failed: \(error.localizedDescription)")
        }
    }
    
    private func saveChanges() async {
        guard !isRecalculating else { return }
        isRecalculating = true
        defer { isRecalculating = false }

        let recordIDs = draftRecordIDs
        let roadNames = draftRoadNames
        let name = draftName
        let caption = aiCaption
        let diary = aiDiary
        let highlights = aiHighlights
        let tone = selectedSummaryTone.rawValue

        do {
            let savedDraft = try await RouteMutationPersistence.commit(
                container: modelContext.container,
                routeID: route.id
            ) { storedRoute, context in
                storedRoute.name = name
                storedRoute.aiSummaryCaption = caption
                storedRoute.aiSummaryDiary = diary
                storedRoute.aiSummaryHighlights = highlights
                storedRoute.aiSummaryToneRawValue = tone

                let recordsByID = Dictionary(
                    uniqueKeysWithValues: storedRoute.photoRecords.map { ($0.id, $0) }
                )
                let removedRecords = storedRoute.photoRecords.filter { !recordIDs.contains($0.id) }
                removedRecords.forEach(context.delete)
                storedRoute.photoRecords = recordIDs.compactMap { recordID in
                    guard let record = recordsByID[recordID] else { return nil }
                    let value = roadNames[recordID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    record.roadName = value.isEmpty ? nil : value
                    return record
                }
            }

            try savedDraft.apply(to: route, in: modelContext)
            dismiss()
        } catch {
            if let mutationError = error as? RouteMutationPersistenceError,
               case .committedMutationUnavailable = mutationError {
                print("Saved route could not be refreshed in the current view.")
                dismiss()
            } else {
                saveErrorMessage = "변경사항이 저장되지 않았습니다. 다시 시도해 주세요.\n\n\(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    private func deleteRoute() async {
        guard !isRecalculating else { return }
        isRecalculating = true
        defer { isRecalculating = false }
        do {
            try RouteMutationPersistence.delete(
                container: modelContext.container,
                routeID: route.id
            )
            dismiss()
        } catch {
            saveErrorMessage = "경로를 삭제하지 못했습니다. 다시 시도해 주세요.\n\n\(error.localizedDescription)"
        }
    }

    private func removeAIHighlight(at index: Int) {
        guard aiHighlights.indices.contains(index) else { return }
        aiHighlights.remove(at: index)
    }

    private func syncStoredAISummary() {
        aiCaption = route.aiSummaryCaption
        aiDiary = route.aiSummaryDiary
        aiHighlights = route.aiSummaryHighlights
        if let storedTone = RouteSummaryTonePreference(rawValue: route.aiSummaryToneRawValue ?? "") {
            selectedSummaryTone = storedTone
        }
    }
}

struct RouteSummaryToneMenu: View {
    @Binding var selection: RouteSummaryTonePreference
    var isDisabled = false

    var body: some View {
        Menu {
            Picker("AI 톤", selection: $selection) {
                ForEach(RouteSummaryTonePreference.allCases) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
        } label: {
            Label(selection.displayName, systemImage: "text.bubble")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(.purple)
        .disabled(isDisabled)
        .accessibilityLabel("AI 톤")
        .accessibilityValue(selection.displayName)
    }
}
