//
//  RouteBottomSheet.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import Photos
import UIKit
import SwiftData

struct RouteBottomSheet: View {
    @ObservedObject var viewModel: RouteMapViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isExporting = false
    
    // AI 관련 상태
    @State private var isGeneratingAI = false
    @State private var aiGenerationStatus = "AI가 경로를 요약하는 중..."
    @State private var isAICompletionVisible = false
    @State private var aiErrorMessage: String?
    @State private var aiCaption: String?
    @State private var aiHighlights: [String] = []
    @State private var selectedSummaryTone: RouteSummaryTonePreference = .warm
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Handle bar
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray3))
                        .frame(width: 40, height: 5)
                    Spacer()
                }
                .padding(.top, 8)
                
                // Title section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.route.name.isEmpty ? "경로 결과" : viewModel.route.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if visibleAICaption == nil {
                            if isGeneratingAI {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                HStack(spacing: 8) {
                                    RouteSummaryToneMenu(selection: $selectedSummaryTone)

                                    Button {
                                        Task { await generateAISummary() }
                                    } label: {
                                        Label("AI 요약", systemImage: "sparkles")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.purple)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(viewModel.route.date.formatted(date: .long, time: .omitted))
                        
                        if let firstRoad = viewModel.route.roadNames.first {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(firstRoad)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    if isGeneratingAI {
                        RouteAIActivityPanel(
                            title: "AI 요약 생성 중",
                            message: aiGenerationStatus,
                            showsSkeleton: true
                        )
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if isAICompletionVisible {
                        RouteAICompletionBadge(message: "AI 요약이 완성되었습니다")
                            .padding(.top, 8)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }

                    if let aiErrorMessage {
                        RouteAIErrorBanner(message: aiErrorMessage)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // AI 요약 결과 표시
                    if let caption = visibleAICaption {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(caption)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if !aiHighlights.isEmpty {
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
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.leading, 8)
                                        .padding(.trailing, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundStyle(.purple)
                                        .clipShape(Capsule())
                                    }
                                }
                            }

                            HStack(spacing: 8) {
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
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                        )
                        .padding(.top, 8)
                    }
                }
                
                // Statistics cards
                HStack(spacing: 12) {
                    StatCard(
                        icon: "figure.walk",
                        title: "거리",
                        value: String(format: "%.1f km", viewModel.route.totalDistance)
                    )
                    
                    StatCard(
                        icon: "clock",
                        title: "소요 시간",
                        value: formatDuration(viewModel.route.duration)
                    )
                }
                
                // Road names section
                if !viewModel.route.roadNames.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("방문한 도로")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.route.roadNames, id: \.self) { roadName in
                                Text(roadName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.primaryBlue.opacity(0.1))
                                    .foregroundStyle(Color.primaryBlue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await shareRouteSnapshot() }
                    } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .disabled(isExporting)
                    
                    Button {
                        Task { await saveRouteSnapshotToPhotos() }
                    } label: {
                        Label("저장", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                }
            }
            .padding()
        }
        .task(id: viewModel.route.id) {
            syncStoredAISummary()
        }
    }

    private var visibleAICaption: String? {
        guard let caption = aiCaption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            return nil
        }

        return caption
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func shareRouteTextFallback() {
        let summaryText = routeShareSummaryText()
        let text = """
        \(viewModel.route.name)
        \(summaryText.isEmpty ? "" : "\(summaryText)\n")거리: \(String(format: "%.1f", viewModel.route.totalDistance))km
        소요 시간: \(formatDuration(viewModel.route.duration))
        """

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC)
    }
    
    private func makeSnapshotImage() async throws -> UIImage {
        let displayCoordinates = viewModel.routedCoordinates.isEmpty ? viewModel.coordinates : viewModel.routedCoordinates
        return try await RouteSnapshotRenderer.renderSnapshot(
            route: viewModel.route,
            pathCoordinates: displayCoordinates,
            size: CGSize(width: 1600, height: 1600),
            scale: UIScreen.main.scale,
            lineWidth: 10
        )
    }

    private func shareRouteSnapshot() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let image = try await makeSnapshotImage()
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            present(activityVC)
        } catch {
            shareRouteTextFallback()
        }
    }

    private func saveRouteSnapshotToPhotos() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let newStatus = await requestPhotoAuthorization()
            if newStatus != .authorized && newStatus != .limited {
                return
            }
        } else if status != .authorized && status != .limited {
            return
        }

        do {
            let image = try await makeSnapshotImage()
            try await saveToPhotoLibrary(image)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func requestPhotoAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success && error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotoRava.RouteSave", code: 1))
                }
            }
        }
    }

    private func present(_ controller: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(controller, animated: true)
    }
    
    @MainActor
    private func generateAISummary() async {
        guard !isGeneratingAI else { return }
        isGeneratingAI = true
        aiErrorMessage = nil
        aiGenerationStatus = "경로 통계를 정리하는 중..."
        isAICompletionVisible = false
        
        let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: viewModel.route)
        
        do {
            withAnimation(.easeInOut(duration: 0.2)) {
                aiGenerationStatus = "AI가 경로를 요약하는 중..."
            }
            
            if #available(iOS 26.0, *) {
                let result = await LocalAIService.shared.routeNarratorResult(
                    snapshot: snapshot,
                    tonePreference: selectedSummaryTone
                )
                withAnimation {
                    aiGenerationStatus = "요약과 하이라이트를 반영하는 중..."
                    viewModel.route.apply(summary: result.summary)
                    syncStoredAISummary()
                    aiErrorMessage = result.fallbackError.map { aiSummaryErrorMessage(for: $0) }
                }
            } else {
                // 하위 버전 fallback
                aiGenerationStatus = "대체 요약을 구성하는 중..."
                try await Task.sleep(nanoseconds: 800_000_000)
                withAnimation {
                    viewModel.route.applyStoredSummary(
                        title: "✨ [AI] \(snapshot.startName) 여정",
                        caption: "약 \(String(format: "%.1f", snapshot.distanceKm))km를 이동한 \(snapshot.timeOfDay ?? "오전")의 기록",
                        diary: viewModel.route.aiSummaryDiary,
                        highlights: ["경로 기록 보완", "요약 생성 완료"],
                        toneRawValue: selectedSummaryTone.rawValue,
                        confidence: nil
                    )
                    syncStoredAISummary()
                    aiErrorMessage = aiSummaryFallbackMessage(for: .requiresIOS26)
                }
            }
            try? modelContext.save()
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isGeneratingAI = false
                isAICompletionVisible = aiErrorMessage == nil
            }
            
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeOut(duration: 0.25)) {
                isAICompletionVisible = false
            }
        } catch {
            withAnimation(.easeOut(duration: 0.2)) {
                isGeneratingAI = false
                aiErrorMessage = aiSummaryErrorMessage(for: error)
            }
            print("AI Summary Generation Failed: \(error.localizedDescription)")
        }
    }

    private func syncStoredAISummary() {
        aiCaption = viewModel.route.aiSummaryCaption
        aiHighlights = viewModel.route.aiSummaryHighlights
        if let storedTone = RouteSummaryTonePreference(rawValue: viewModel.route.aiSummaryToneRawValue ?? "") {
            selectedSummaryTone = storedTone
        }
    }

    private func removeAIHighlight(at index: Int) {
        guard aiHighlights.indices.contains(index) else { return }
        aiHighlights.remove(at: index)
        viewModel.route.aiSummaryHighlights = aiHighlights
        try? modelContext.save()
    }

    private func routeShareSummaryText() -> String {
        var parts: [String] = []

        if let caption = viewModel.route.aiSummaryCaption,
           !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(caption)
        }

        if !viewModel.route.aiSummaryHighlights.isEmpty {
            parts.append(viewModel.route.aiSummaryHighlights.prefix(3).joined(separator: " · "))
        }

        return parts.joined(separator: "\n")
    }

    private func aiSummaryErrorMessage(for error: Error) -> String {
        if #available(iOS 26.0, *),
           let localAIError = error as? LocalAIService.LocalAIError {
            return aiSummaryFallbackMessage(for: localAIError.availabilityIssue)
        }
        return "AI 요약 생성에 실패해 대체 요약을 표시합니다. 잠시 후 다시 시도해 주세요."
    }

    private func aiSummaryFallbackMessage(for issue: LocalAIAvailabilityIssue) -> String {
        switch issue {
        case .requiresIOS26:
            return "iOS 26 이상에서 Apple Intelligence 요약을 사용할 수 있어 대체 요약을 표시합니다."
        case .deviceNotEligible:
            return "이 기기는 Apple Intelligence를 지원하지 않아 대체 요약을 표시합니다."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence가 꺼져 있어 대체 요약을 표시합니다. 설정에서 활성화한 뒤 다시 시도해 주세요."
        case .modelNotReady:
            return "Apple Intelligence 모델 준비가 끝나지 않아 대체 요약을 표시합니다. 준비가 완료되면 다시 시도해 주세요."
        case .unsupportedLocale:
            return "현재 언어 설정에서는 Apple Intelligence 요약을 사용할 수 없어 대체 요약을 표시합니다."
        case .invalidOutput:
            return "AI 응답 형식이 올바르지 않아 대체 요약을 표시합니다. 다시 시도해 주세요."
        case .unavailable:
            return "Apple Intelligence를 사용할 수 없어 대체 요약을 표시합니다."
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.primaryBlue)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RouteAIActivityPanel: View {
    let title: String
    let message: String
    let showsSkeleton: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                Spacer(minLength: 8)
                
                ProgressView()
                    .controlSize(.small)
                    .tint(.purple)
            }
            
            if showsSkeleton {
                VStack(alignment: .leading, spacing: 8) {
                    RouteAIShimmerLine(widthRatio: 0.88)
                    RouteAIShimmerLine(widthRatio: 0.68)
                    RouteAIShimmerLine(widthRatio: 0.78)
                    
                    HStack(spacing: 6) {
                        RouteAIShimmerCapsule(width: 74)
                        RouteAIShimmerCapsule(width: 92)
                        RouteAIShimmerCapsule(width: 64)
                    }
                    .padding(.top, 2)
                }
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct RouteAICompletionBadge: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.primaryBlue)
            
            Text(message)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primaryBlue.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct RouteAIErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct RouteAIShimmerLine: View {
    let widthRatio: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            shimmerBase(cornerRadius: 4)
                .frame(width: max(geometry.size.width * widthRatio, 52), height: 10)
                .overlay(shimmerOverlay(width: geometry.size.width))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 10)
        .onAppear(perform: startAnimation)
    }
    
    private func shimmerBase(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
    }
    
    private func shimmerOverlay(width: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.72),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: max(width * 0.45, 80), height: 24)
        .rotationEffect(.degrees(8))
        .offset(x: isAnimating ? width : -width)
    }
    
    private func startAnimation() {
        isAnimating = false
        withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
}

private struct RouteAIShimmerCapsule: View {
    let width: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(width: width, height: 20)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.72),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 56, height: 28)
                .rotationEffect(.degrees(8))
                .offset(x: isAnimating ? width : -width)
            )
            .clipShape(Capsule())
            .onAppear {
                isAnimating = false
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// FlowLayout for road name tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
