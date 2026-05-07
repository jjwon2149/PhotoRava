//
//  RouteEditView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData
import UIKit

struct RouteEditView: View {
    @Bindable var route: Route
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteAlert = false
    @State private var showingSettingsOpenError = false
    @State private var isRecalculating = false
    
    // AI 관련 상태
    @State private var isGeneratingAI = false
    @State private var aiCaption: String?
    @State private var aiDiary: String?
    @State private var aiHighlights: [String] = []
    @State private var aiAvailabilityIssue: LocalAIAvailabilityIssue?
    
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
                            .accessibilityLabel(aiAvailabilityIssue == nil ? "AI 요약 생성" : "기본 요약 생성")
                        }
                    }

                    if let aiAvailabilityIssue {
                        LocalAIAvailabilityBanner(issue: aiAvailabilityIssue) {
                            openAppleIntelligenceSettings()
                        }
                    }
                    
                    // AI 요약 결과 및 감성 일기 미리보기
                    if let caption = aiCaption {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(
                                    isShowingFallbackSummary ? "기본 여행 기록" : "AI의 여행 기록",
                                    systemImage: isShowingFallbackSummary ? "doc.text" : "sparkles"
                                )
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(isShowingFallbackSummary ? Color.secondary : Color.purple)
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
                                                    .background((isShowingFallbackSummary ? Color.secondary : Color.purple).opacity(0.1))
                                                    .foregroundStyle(isShowingFallbackSummary ? Color.secondary : Color.purple)
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
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } footer: {
                    if aiCaption == nil && aiAvailabilityIssue == nil {
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
            .alert("설정 앱을 열 수 없습니다", isPresented: $showingSettingsOpenError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("설정 앱에서 Apple Intelligence 상태를 직접 확인해주세요.")
            }
            .task(id: route.id) {
                syncStoredAISummary()
                await refreshAIAvailabilityIssue()
            }
        }
    }

    private var isShowingFallbackSummary: Bool {
        aiAvailabilityIssue != nil && route.aiSummaryConfidence == nil
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        route.photoRecords.remove(atOffsets: offsets)
    }
    
    private func moveRecords(from source: IndexSet, to destination: Int) {
        route.photoRecords.move(fromOffsets: source, toOffset: destination)
    }
    
    @MainActor
    private func generateAISummary() async {
        isGeneratingAI = true
        defer { isGeneratingAI = false }
        
        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)
        
        do {
            if #available(iOS 26.0, *) {
                aiAvailabilityIssue = LocalAIService.shared.routeSummaryAvailabilityIssue()
                if aiAvailabilityIssue != nil {
                    await applyFallbackSummary(for: snapshot)
                    try? modelContext.save()
                    return
                }

                let summary = try await LocalAIService.shared.routeNarrator(snapshot: snapshot)
                withAnimation {
                    self.route.apply(summary: summary)
                    syncStoredAISummary()
                }
            } else {
                aiAvailabilityIssue = .requiresIOS26
                await applyFallbackSummary(for: snapshot)
            }
            try? modelContext.save()
        } catch {
            if #available(iOS 26.0, *),
               let localAIError = error as? LocalAIService.LocalAIError {
                aiAvailabilityIssue = localAIError.availabilityIssue
            } else {
                aiAvailabilityIssue = .unavailable
            }
            await applyFallbackSummary(for: snapshot)
            try? modelContext.save()
            print("AI summary generation failed: \(error.localizedDescription)")
        }
    }
    
    private func saveChanges() async {
        isRecalculating = true
        
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

    private func syncStoredAISummary() {
        aiCaption = route.aiSummaryCaption
        aiDiary = route.aiSummaryDiary
        aiHighlights = route.aiSummaryHighlights
    }

    @MainActor
    private func refreshAIAvailabilityIssue() async {
        if #available(iOS 26.0, *) {
            aiAvailabilityIssue = LocalAIService.shared.routeSummaryAvailabilityIssue()
        } else {
            aiAvailabilityIssue = .requiresIOS26
        }
    }

    @MainActor
    private func applyFallbackSummary(for snapshot: RouteStatsSnapshot) async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation {
            route.applyStoredSummary(
                title: "\(snapshot.startName) 여정",
                caption: "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동한 \(snapshot.timeOfDay ?? "오전")의 기록",
                diary: "\(snapshot.timeOfDay ?? "오후")의 햇살이 따뜻했던 날, \(snapshot.startName)에서 여정을 시작했습니다. 발길 닿는 곳마다 펼쳐진 풍경들은 제법 낭만적이었고, \(snapshot.durationMin)분간의 시간은 온전히 저만의 여행이 되었습니다.",
                highlights: ["기본 요약", "경로 기록 보완", "이동 흐름 정리"],
                toneRawValue: nil,
                confidence: nil
            )
            syncStoredAISummary()
        }
    }

    private func openAppleIntelligenceSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            showingSettingsOpenError = true
            return
        }
        guard UIApplication.shared.canOpenURL(url) else {
            showingSettingsOpenError = true
            return
        }
        openURL(url)
    }
}

private struct LocalAIAvailabilityBanner: View {
    let issue: LocalAIAvailabilityIssue
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.systemImageName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(issue.tintColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 6) {
                Text(issue.bannerTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(issue.bannerMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if issue.showsSettingsButton {
                    Button(action: onOpenSettings) {
                        Label("설정 열기", systemImage: "gearshape")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(issue.tintColor)
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(issue.tintColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(issue.tintColor.opacity(0.24), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

private extension LocalAIAvailabilityIssue {
    var bannerTitle: String {
        switch self {
        case .requiresIOS26:
            return "AI 요약은 iOS 26 이상에서 지원됩니다"
        case .deviceNotEligible:
            return "이 기기는 Apple Intelligence를 지원하지 않습니다"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence가 꺼져 있습니다"
        case .modelNotReady:
            return "AI 모델을 준비 중입니다"
        case .unsupportedLocale:
            return "현재 언어 설정에서는 AI 요약을 사용할 수 없습니다"
        case .invalidOutput:
            return "AI 응답을 적용하지 못했습니다"
        case .unavailable:
            return "AI 요약을 사용할 수 없습니다"
        }
    }

    var bannerMessage: String {
        switch self {
        case .requiresIOS26:
            return "현재 환경에서는 기본 요약을 대신 표시합니다."
        case .deviceNotEligible:
            return "지원 기기에서만 온디바이스 AI 여행 기록을 만들 수 있습니다. 지금은 기본 요약을 대신 표시합니다."
        case .appleIntelligenceNotEnabled:
            return "설정 앱에서 Apple Intelligence를 켜면 AI 여행 기록을 만들 수 있습니다. 지금은 기본 요약을 대신 표시합니다."
        case .modelNotReady:
            return "온디바이스 모델 다운로드 또는 준비가 끝나면 AI 요약을 사용할 수 있습니다. 지금은 기본 요약을 대신 표시합니다."
        case .unsupportedLocale:
            return "한국어 또는 현재 기기 언어를 지원하지 않는 상태입니다. 지금은 기본 요약을 대신 표시합니다."
        case .invalidOutput:
            return "생성된 응답 형식이 맞지 않아 기본 요약을 대신 표시합니다."
        case .unavailable:
            return "일시적으로 AI 요약을 만들 수 없어 기본 요약을 대신 표시합니다."
        }
    }

    var showsSettingsButton: Bool {
        self == .appleIntelligenceNotEnabled
    }

    var systemImageName: String {
        switch self {
        case .appleIntelligenceNotEnabled:
            return "gearshape"
        case .modelNotReady:
            return "clock"
        case .deviceNotEligible, .requiresIOS26:
            return "iphone.slash"
        case .unsupportedLocale:
            return "globe"
        case .invalidOutput:
            return "exclamationmark.triangle"
        case .unavailable:
            return "sparkles"
        }
    }

    var tintColor: Color {
        switch self {
        case .appleIntelligenceNotEnabled, .modelNotReady:
            return .orange
        case .deviceNotEligible, .requiresIOS26, .unsupportedLocale:
            return .secondary
        case .invalidOutput, .unavailable:
            return .red
        }
    }
}
