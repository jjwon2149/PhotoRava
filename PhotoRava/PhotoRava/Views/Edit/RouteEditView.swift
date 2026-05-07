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

    // AI 관련 상태
    @State private var isGeneratingAI = false
    @State private var regeneratingField: AISummaryField?

    private enum AISummaryField {
        case title
        case caption
        case diary
        case highlights
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryTitleRow

                    if hasAISummary {
                        aiSummaryEditor
                    } else {
                        Button {
                            Task { await generateAISummary() }
                        } label: {
                            Label("AI 여행 기록 만들기", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .disabled(summaryActionDisabled)
                    }
                } footer: {
                    if !hasAISummary {
                        Text("✨ 마법봉을 눌러 AI가 제안하는 매력적인 제목과 일기를 만들어보세요.")
                    }
                }

                Section("사진 (\(route.photoRecords.count)개)") {
                    ForEach(route.photoRecords) { record in
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
                                    get: { record.roadName ?? "" },
                                    set: { record.roadName = $0.isEmpty ? nil : $0 }
                                ))
                                .font(.subheadline)

                                Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isRecalculating {
                        ProgressView()
                    } else {
                        Button("완료") {
                            Task {
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
            .alert("경로 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteRoute()
                }
            } message: {
                Text("이 경로를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
        }
    }

    private var summaryTitleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("제목", systemImage: "textformat")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                regenerateButton(for: .title)
            }

            TextField("경로 이름", text: titleBinding, axis: .vertical)
                .font(.headline)
                .lineLimit(1...2)
        }
        .padding(.vertical, 4)
    }

    private var aiSummaryEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI의 여행 기록", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)

                Spacer()

                if isGeneratingAI {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await generateAISummary() }
                    } label: {
                        Label("전체 다시 생성", systemImage: "sparkles")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .controlSize(.mini)
                    .disabled(summaryActionDisabled)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                editableSummaryText(
                    title: "캡션",
                    field: .caption,
                    text: captionBinding,
                    prompt: "한 줄 요약",
                    font: .subheadline.weight(.bold),
                    foregroundColor: .primary,
                    lineLimit: 1...3
                )

                editableSummaryText(
                    title: "일기",
                    field: .diary,
                    text: diaryBinding,
                    prompt: "여정 일기",
                    font: .system(size: 14, weight: .regular, design: .serif),
                    foregroundColor: .secondary,
                    lineLimit: 3...8
                )

                editableHighlights
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.vertical, 8)
    }

    private func editableSummaryText(
        title: String,
        field: AISummaryField,
        text: Binding<String>,
        prompt: String,
        font: Font,
        foregroundColor: Color,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                regenerateButton(for: field)
            }

            TextField(prompt, text: text, axis: .vertical)
                .font(font)
                .foregroundStyle(foregroundColor)
                .lineLimit(lineLimit)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        }
    }

    private var editableHighlights: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("하이라이트")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                regenerateButton(for: .highlights)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(route.aiSummaryHighlights.indices), id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("하이라이트", text: highlightBinding(at: index), axis: .vertical)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1...2)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(role: .destructive) {
                            removeHighlight(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("하이라이트 삭제")
                    }
                }

                Button {
                    appendHighlight()
                } label: {
                    Label("하이라이트 추가", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.purple)
                .disabled(route.aiSummaryHighlights.count >= 3)
            }
        }
    }

    private func regenerateButton(for field: AISummaryField) -> some View {
        Group {
            if regeneratingField == field {
                ProgressView()
                    .controlSize(.small)
                    .frame(minWidth: 82, alignment: .trailing)
            } else {
                Button {
                    Task { await regenerateAISummaryField(field) }
                } label: {
                    Label("다시 생성", systemImage: "arrow.clockwise")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.mini)
                .disabled(summaryActionDisabled)
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { route.name },
            set: { newValue in
                route.name = newValue
                route.userEditedTitle = storedEditedText(from: newValue)
            }
        )
    }

    private var captionBinding: Binding<String> {
        Binding(
            get: { route.aiSummaryCaption ?? "" },
            set: { newValue in
                route.aiSummaryCaption = newValue
                route.userEditedCaption = storedEditedText(from: newValue)
            }
        )
    }

    private var diaryBinding: Binding<String> {
        Binding(
            get: { route.aiSummaryDiary ?? "" },
            set: { newValue in
                route.aiSummaryDiary = newValue
                route.userEditedDiaryEntry = storedEditedText(from: newValue)
            }
        )
    }

    private func highlightBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard route.aiSummaryHighlights.indices.contains(index) else { return "" }
                return route.aiSummaryHighlights[index]
            },
            set: { newValue in
                guard route.aiSummaryHighlights.indices.contains(index) else { return }
                route.aiSummaryHighlights[index] = newValue
                storeEditedHighlights()
            }
        )
    }

    private var hasAISummary: Bool {
        route.aiSummaryCaption != nil ||
        route.aiSummaryDiary != nil ||
        !route.aiSummaryHighlights.isEmpty
    }

    private var summaryActionDisabled: Bool {
        isGeneratingAI || regeneratingField != nil
    }

    private func deleteRecords(at offsets: IndexSet) {
        route.photoRecords.remove(atOffsets: offsets)
    }

    private func moveRecords(from source: IndexSet, to destination: Int) {
        route.photoRecords.move(fromOffsets: source, toOffset: destination)
    }

    @MainActor
    private func generateAISummary() async {
        guard !summaryActionDisabled else { return }

        isGeneratingAI = true
        defer { isGeneratingAI = false }

        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)

        do {
            if #available(iOS 26.0, *) {
                let summary = try await LocalAIService.shared.routeNarrator(snapshot: snapshot)
                withAnimation {
                    self.route.apply(summary: summary)
                    self.route.clearUserEditedSummary()
                }
            } else {
                // 하위 버전 fallback
                try await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation {
                    self.route.applyStoredSummary(
                        title: fallbackTitle(for: snapshot),
                        caption: fallbackCaption(for: snapshot),
                        diary: fallbackDiary(for: snapshot),
                        highlights: fallbackHighlights(for: snapshot),
                        toneRawValue: nil,
                        confidence: nil
                    )
                    self.route.clearUserEditedSummary()
                }
            }
            try? modelContext.save()
        } catch {
            print("AI summary generation failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func regenerateAISummaryField(_ field: AISummaryField) async {
        guard !summaryActionDisabled else { return }

        regeneratingField = field
        defer { regeneratingField = nil }

        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)

        do {
            if #available(iOS 26.0, *) {
                let summary = try await LocalAIService.shared.routeNarrator(snapshot: snapshot)
                withAnimation {
                    applyGeneratedSummary(summary, replacing: field)
                }
            } else {
                try await Task.sleep(nanoseconds: 800_000_000)
                withAnimation {
                    applyFallbackSummaryField(field, snapshot: snapshot)
                }
            }
            try? modelContext.save()
        } catch {
            print("AI summary field regeneration failed: \(error.localizedDescription)")
        }
    }

    @available(iOS 26.0, *)
    private func applyGeneratedSummary(_ summary: RouteSummary, replacing field: AISummaryField) {
        switch field {
        case .title:
            route.name = summary.title
        case .caption:
            route.aiSummaryCaption = summary.caption
        case .diary:
            route.aiSummaryDiary = summary.diaryEntry
        case .highlights:
            route.aiSummaryHighlights = summary.highlights
        }

        route.aiSummaryToneRawValue = summary.tone.rawValue
        route.aiSummaryConfidence = summary.confidence
        route.aiSummaryGeneratedAt = Date()
        clearUserEditedValue(for: field)
    }

    private func applyFallbackSummaryField(_ field: AISummaryField, snapshot: RouteStatsSnapshot) {
        switch field {
        case .title:
            route.name = fallbackTitle(for: snapshot)
        case .caption:
            route.aiSummaryCaption = fallbackCaption(for: snapshot)
        case .diary:
            route.aiSummaryDiary = fallbackDiary(for: snapshot)
        case .highlights:
            route.aiSummaryHighlights = fallbackHighlights(for: snapshot)
        }

        route.aiSummaryToneRawValue = nil
        route.aiSummaryConfidence = nil
        route.aiSummaryGeneratedAt = Date()
        clearUserEditedValue(for: field)
    }

    private func saveChanges() async {
        isRecalculating = true

        route.aiSummaryHighlights = cleanedHighlights(from: route.aiSummaryHighlights)
        if !route.userEditedHighlights.isEmpty {
            route.userEditedHighlights = route.aiSummaryHighlights
        }

        // 파생 데이터 재계산 (Feature 3: 최적화 로직 포함됨)
        await RouteReconstructionService.shared.recalculateRouteData(for: route, modelContext: modelContext)

        // SwiftData에 저장
        try? modelContext.save()

        isRecalculating = false
        dismiss()
    }

    private func deleteRoute() {
        modelContext.delete(route)
        try? modelContext.save()
        dismiss()
    }

    private func appendHighlight() {
        guard route.aiSummaryHighlights.count < 3 else { return }
        route.aiSummaryHighlights.append("")
        storeEditedHighlights()
    }

    private func removeHighlight(at index: Int) {
        guard route.aiSummaryHighlights.indices.contains(index) else { return }
        route.aiSummaryHighlights.remove(at: index)
        storeEditedHighlights()
    }

    private func storeEditedHighlights() {
        route.userEditedHighlights = cleanedHighlights(from: route.aiSummaryHighlights)
    }

    private func clearUserEditedValue(for field: AISummaryField) {
        switch field {
        case .title:
            route.userEditedTitle = nil
        case .caption:
            route.userEditedCaption = nil
        case .diary:
            route.userEditedDiaryEntry = nil
        case .highlights:
            route.userEditedHighlights = []
        }
    }

    private func storedEditedText(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func cleanedHighlights(from values: [String]) -> [String] {
        values.compactMap { value in
            guard let edited = storedEditedText(from: value) else { return nil }
            return String(edited.prefix(20))
        }
    }

    private func fallbackTitle(for snapshot: RouteStatsSnapshot) -> String {
        "✨ [AI] \(snapshot.startName) 여정"
    }

    private func fallbackCaption(for snapshot: RouteStatsSnapshot) -> String {
        "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동한 \(snapshot.timeOfDay ?? "오전")의 기록"
    }

    private func fallbackDiary(for snapshot: RouteStatsSnapshot) -> String {
        "\(snapshot.timeOfDay ?? "오후")의 햇살이 따뜻했던 날, \(snapshot.startName)에서 여정을 시작했습니다. 발길 닿는 곳마다 펼쳐진 풍경들은 제법 낭만적이었고, \(snapshot.durationMin)분간의 시간은 온전히 저만의 여행이 되었습니다."
    }

    private func fallbackHighlights(for snapshot: RouteStatsSnapshot) -> [String] {
        ["경로 기록 보완", "감성 요약 생성", "\(snapshot.durationMin)분 기록"]
    }
}
