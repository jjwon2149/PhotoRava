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
    @State private var aiGenerationStatus = "AI가 경로를 요약하는 중..."
    @State private var isAICompletionVisible = false
    @State private var recalculationStatus = "변경 사항 저장 중..."
    @State private var aiCaption: String?
    @State private var aiDiary: String?
    @State private var aiHighlights: [String] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("경로 이름", text: $route.name)
                            .font(.headline)
                        
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
                    
                    if isGeneratingAI {
                        RouteAIActivityPanel(
                            title: "AI 여행 기록 생성 중",
                            message: aiGenerationStatus,
                            showsSkeleton: true
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if isAICompletionVisible {
                        RouteAICompletionBadge(message: "AI 여행 기록이 완성되었습니다")
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }
                    
                    if isRecalculating {
                        RouteAIActivityPanel(
                            title: "경로 변경 사항 저장 중",
                            message: recalculationStatus,
                            showsSkeleton: false
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // AI 요약 결과 및 감성 일기 미리보기
                    if let caption = aiCaption {
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
                                            ForEach(aiHighlights, id: \.self) { highlight in
                                                Text(highlight)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .padding(.horizontal, 8)
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
                                .disabled(isGeneratingAI)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } footer: {
                    if aiCaption == nil && !isGeneratingAI {
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
            .task(id: route.id) {
                syncStoredAISummary()
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        route.photoRecords.remove(atOffsets: offsets)
    }
    
    private func moveRecords(from source: IndexSet, to destination: Int) {
        route.photoRecords.move(fromOffsets: source, toOffset: destination)
    }
    
    @MainActor
    private func generateAISummary() async {
        guard !isGeneratingAI else { return }
        isGeneratingAI = true
        aiGenerationStatus = "경로 통계를 정리하는 중..."
        isAICompletionVisible = false
        
        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)
        
        do {
            withAnimation(.easeInOut(duration: 0.2)) {
                aiGenerationStatus = "AI가 경로를 요약하는 중..."
            }
            
            if #available(iOS 26.0, *) {
                let summary = try await LocalAIService.shared.routeNarrator(snapshot: snapshot)
                withAnimation {
                    aiGenerationStatus = "제목과 여행 기록을 반영하는 중..."
                    self.route.apply(summary: summary)
                    syncStoredAISummary()
                }
            } else {
                // 하위 버전 fallback
                aiGenerationStatus = "대체 요약을 구성하는 중..."
                try await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation {
                    self.route.applyStoredSummary(
                        title: "✨ [AI] \(snapshot.startName) 여정",
                        caption: "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동한 \(snapshot.timeOfDay ?? "오전")의 기록",
                        diary: "\(snapshot.timeOfDay ?? "오후")의 햇살이 따뜻했던 날, \(snapshot.startName)에서 여정을 시작했습니다. 발길 닿는 곳마다 펼쳐진 풍경들은 제법 낭만적이었고, \(snapshot.durationMin)분간의 시간은 온전히 저만의 여행이 되었습니다.",
                        highlights: ["경로 기록 보완", "감성 요약 생성", "이동 흐름 정리"],
                        toneRawValue: nil,
                        confidence: nil
                    )
                    syncStoredAISummary()
                }
            }
            try? modelContext.save()
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isGeneratingAI = false
                isAICompletionVisible = true
            }
            
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeOut(duration: 0.25)) {
                isAICompletionVisible = false
            }
        } catch {
            withAnimation(.easeOut(duration: 0.2)) {
                isGeneratingAI = false
            }
            print("AI summary generation failed: \(error.localizedDescription)")
        }
    }
    
    private func saveChanges() async {
        isRecalculating = true
        recalculationStatus = routeHasAIGeocodeCandidates ? "AI 위치 보정 후보를 확인하는 중..." : "경로 통계를 다시 계산하는 중..."
        
        // 파생 데이터 재계산 (Feature 3: 최적화 로직 포함됨)
        await RouteReconstructionService.shared.recalculateRouteData(for: route, modelContext: modelContext)
        
        // SwiftData에 저장
        recalculationStatus = "SwiftData에 변경 사항을 저장하는 중..."
        try? modelContext.save()
        
        isRecalculating = false
        dismiss()
    }
    
    private func deleteRoute() {
        modelContext.delete(route)
        try? modelContext.save()
        dismiss()
    }

    private func syncStoredAISummary() {
        aiCaption = route.aiSummaryCaption
        aiDiary = route.aiSummaryDiary
        aiHighlights = route.aiSummaryHighlights
    }
    
    private var routeHasAIGeocodeCandidates: Bool {
        route.photoRecords.contains { record in
            guard record.latitude == nil || record.longitude == nil else { return false }
            
            if let roadName = record.roadName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !roadName.isEmpty {
                return true
            }
            
            if let rawOCRText = record.rawOCRText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawOCRText.isEmpty {
                return true
            }
            
            return !record.topOCRCandidates.isEmpty
        }
    }
}
