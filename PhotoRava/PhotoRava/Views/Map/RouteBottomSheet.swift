//
//  RouteBottomSheet.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import Photos
import UIKit

struct RouteBottomSheet: View {
    @ObservedObject var viewModel: RouteMapViewModel
    @State private var isExporting = false
    
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
                    Text("경로 결과")
                        .font(.title2)
                        .fontWeight(.bold)
                    
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
        let text = """
        \(viewModel.route.name)
        거리: \(String(format: "%.1f", viewModel.route.totalDistance))km
        소요 시간: \(formatDuration(viewModel.route.duration))
        """

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC)
    }
    
    private func makeSnapshotImage() async throws -> UIImage {
        try await RouteSnapshotRenderer.renderSnapshot(
            route: viewModel.route,
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
