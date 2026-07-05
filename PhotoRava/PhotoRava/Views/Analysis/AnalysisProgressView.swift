//
//  AnalysisProgressView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData
import ImageIO
import CoreGraphics

struct AnalysisProgressView: View {
    let photos: [LoadedPhoto]
    @StateObject private var viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    init(photos: [LoadedPhoto]) {
        self.photos = photos
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(photos: photos))
    }
    
    var body: some View {
        Group {
            if let route = viewModel.completedRoute {
                RouteMapView(route: route, onBack: { dismiss() })
            } else {
                ZStack {
                    // Blurred background
                    backgroundView
                    
                    VStack(spacing: 24) {
                        // Title
                        VStack(spacing: 8) {
                            Text(viewModel.currentStep.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(viewModel.currentStep.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Circular Progress
                        circularProgressView
                        
                        // Linear Progress
                        linearProgressView
                        
                        Text("사진 원본은 서버 업로드 없이 이 기기에서 분석합니다. 취소하면 저장하지 않고 이전 화면으로 돌아갑니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)

                        statusIndicator
                    }
                    .padding()
                }
                .overlay(alignment: .topLeading) {
                    Button {
                        viewModel.cancelAnalysis()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("경로 분석 취소")
                    .accessibilityHint("현재 분석을 중단하고 저장하지 않은 채 이전 화면으로 돌아갑니다.")
                    .padding()
                }
                .task {
                    viewModel.modelContext = modelContext
                    await viewModel.startAnalysis()
                }
            }
        }
        .alert("분석 오류", isPresented: $viewModel.showingError) {
            Button("다시 시도") {
                Task {
                    await viewModel.startAnalysis()
                }
            }

            Button("사진 다시 선택") {
                dismiss()
            }

            Button("닫기", role: .cancel) {}
        } message: {
            Text(viewModel.errorRecoveryMessage)
        }
    }
    
    private var backgroundView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(photos.prefix(12)) { photo in
                    Image(uiImage: photo.image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                }
            }
        }
        .blur(radius: 10)
        .opacity(0.3)
        .allowsHitTesting(false)
    }
    
    private var circularProgressView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
                .frame(width: 176, height: 176)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    Color.primaryBlue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            
            // Text
            VStack(spacing: 4) {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                
                Text("분석 중")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryBlue)
            }
            
            // Pulse animation
            Circle()
                .stroke(Color.primaryBlue.opacity(0.3), lineWidth: 2)
                .frame(width: 196, height: 196)
                .scaleEffect(viewModel.isPulsing ? 1.1 : 1.0)
                .opacity(viewModel.isPulsing ? 0 : 1)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: viewModel.isPulsing
                )
        }
        .onAppear {
            viewModel.isPulsing = true
        }
    }
    
    private var linearProgressView: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.progressTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(viewModel.currentStep.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.primaryBlue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primaryBlue)
                        .frame(width: geometry.size.width * viewModel.progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 32)
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.primaryBlue)
                .frame(width: 8, height: 8)
                .scaleEffect(viewModel.isPulsing ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: viewModel.isPulsing
                )
            
            Text("사진 원본 서버 업로드 없음")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .accessibilityLabel("사진 원본은 서버에 업로드하지 않고 분석 중")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

enum AnalysisStep {
    case metadata
    case ocr
    case route
    case summary

    var copy: (title: String, subtitle: String, context: String) {
        switch self {
        case .metadata:
            return (
                "사진 정보 확인 중",
                "촬영 시간과 GPS 정보를 먼저 정리합니다",
                "원본 사진에서 날짜, 시간, 위치 정보를 확인하고 있어요."
            )
        case .ocr:
            return (
                "위치 단서 읽는 중",
                "GPS가 없는 사진은 글자 단서를 확인합니다",
                "표지판, 영수증, 장소 이름 같은 글자를 위치 단서로 살펴봅니다."
            )
        case .route:
            return (
                "지도 경로 만드는 중",
                "확인한 사진을 시간순 경로로 연결합니다",
                "정렬된 사진을 지도 경로와 타임라인으로 묶는 단계입니다."
            )
        case .summary:
            return (
                "여정 요약 준비 중",
                "완성된 경로를 보기 좋게 정리합니다",
                "잠시 후 저장된 경로 지도로 바로 이동합니다."
            )
        }
    }

    var title: String { copy.title }
    var subtitle: String { copy.subtitle }
    var context: String { copy.context }
}

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var processedCount: Int = 0
    @Published var currentStep: AnalysisStep = .metadata
    @Published var isPulsing: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var completedRoute: Route?
    
    let photos: [LoadedPhoto]
    var totalCount: Int { photos.count }

    var progressTitle: String {
        switch currentStep {
        case .route, .summary:
            return "\(totalCount)장 확인 완료"
        case .metadata, .ocr:
            return "\(processedCount)/\(totalCount)장 확인 중"
        }
    }

    var errorRecoveryMessage: String {
        let detail = errorMessage.isEmpty ? "알 수 없는 오류가 발생했습니다." : errorMessage
        return """
        \(detail)

        같은 사진으로 다시 시도하거나, 사진을 다시 선택해 GPS가 있는 사진을 더해 보세요.
        """
    }
    
    private let ocrService = OCRService()
    private let metadataService = PhotoMetadataService()
    private var isCancelled = false
    var modelContext: ModelContext?
    
    init(photos: [LoadedPhoto]) {
        self.photos = photos
    }
    
    func startAnalysis() async {
        resetProgressForNewRun()

        var photoRecords: [PhotoRecord] = []
        
        // Step 1: 메타데이터 추출 및 시간순 정렬
        currentStep = .metadata
        
        var photosWithMetadata: [(photo: LoadedPhoto, metadata: PhotoMetadata)] = []
        
        for (index, photo) in photos.enumerated() {
            guard !isCancelled else { break }
            
            let metadata = await metadataService.extractMetadata(from: photo.image, asset: photo.asset, originalData: photo.originalData)
            photosWithMetadata.append((photo, metadata))
            
            processedCount = index + 1
            progress = Double(processedCount) / Double(max(totalCount, 1)) * 0.3
        }
        
        // 촬영 시간순 정렬
        photosWithMetadata.sort { $0.metadata.capturedAt < $1.metadata.capturedAt }
        
        // Step 2: OCR 실행 (GPS 없는 사진에만)
        let needsOCRCount = photosWithMetadata.filter { $0.metadata.coordinate == nil }.count
        if needsOCRCount > 0 {
            currentStep = .ocr
        }
        
        for (index, item) in photosWithMetadata.enumerated() {
            guard !isCancelled else { break }
            
            let photo = item.photo
            let metadata = item.metadata
            
            // OCR 실행 (GPS 없는 경우에만)
            var roadName: String?
            var confidence: Float = 0
            var rawOCRText: String?
            var topOCRCandidates: [String] = []
            
            if metadata.coordinate == nil {
                do {
                    let recognizedTexts = try await ocrService.recognizeText(in: photo.image)
                    
                    // AI 분석을 위한 원본 데이터 보관
                    rawOCRText = recognizedTexts.map { $0.rawText }.joined(separator: "\n")
                    topOCRCandidates = ocrService.topScoredCandidates(from: recognizedTexts, limit: 5).map { $0.candidate.text }
                    
                    // 가장 신뢰도 높은 도로명 선택
                    if let best = ocrService.bestRoadName(from: recognizedTexts) {
                        roadName = best.text
                        confidence = best.confidence
                    }
                } catch {
                    print("OCR failed for photo \(index): \(error)")
                }
            }
            
            // PhotoRecord 생성
            let record = PhotoRecord(capturedAt: metadata.capturedAt)
            
            // 이미지 데이터 저장 - PHAsset이 있으면 원본 데이터 사용, 없으면 압축
            if let asset = photo.asset {
                // 원본 이미지 데이터 가져오기 (메타데이터 보존)
                if let originalData = await metadataService.fetchOriginalImageData(for: asset) {
                    // 원본 데이터가 너무 크면 적절히 압축 (하지만 메타데이터는 보존)
                    if originalData.count > 5_000_000 { // 5MB 이상이면
                        // 메타데이터를 보존하면서 압축
                        record.imageData = await compressImageWithMetadataPreservation(
                            originalData: originalData,
                            maxSize: 2_000_000 // 2MB로 제한
                        )
                    } else {
                        record.imageData = originalData
                    }
                } else {
                    // 원본을 못 가져오면 fallback
                    record.imageData = photo.image.jpegData(compressionQuality: 0.8)
                }
            } else {
                // PHAsset이 없으면 압축 저장
                // 원본 데이터가 있으면 메타데이터 보존을 위해 우선 사용
                record.imageData = photo.originalData ?? photo.image.jpegData(compressionQuality: 0.8)
            }
            
            record.roadName = roadName
            record.ocrConfidence = confidence
            record.rawOCRText = rawOCRText
            record.topOCRCandidates = topOCRCandidates
            record.latitude = metadata.coordinate?.latitude
            record.longitude = metadata.coordinate?.longitude
            
            photoRecords.append(record)
            
            // 진행률 업데이트
            processedCount = index + 1
            let base = Double(processedCount) / Double(max(totalCount, 1))
            progress = 0.3 + base * 0.6
            
            // UI 업데이트를 위한 짧은 딜레이
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        guard !isCancelled else { return }
        
        // Step 3: 경로 재구성
        currentStep = .route
        processedCount = totalCount
        progress = 0.95
        
        do {
            let route = try await RouteReconstructionService.shared.reconstructRoute(
                from: photoRecords,
                modelContext: modelContext
            )

            currentStep = .summary
            progress = 0.98

            let snapshot = RouteReconstructionService.shared.buildStatsSnapshot(for: route)
            if #available(iOS 26.0, *) {
                if let summary = try? await LocalAIService.shared.routeNarrator(snapshot: snapshot) {
                    route.apply(summary: summary)
                }
            } else {
                let summary = RouteStoredSummary.fallback(
                    for: snapshot,
                    tonePreference: .warm
                )
                route.applyStoredSummary(
                    title: summary.title,
                    caption: summary.caption,
                    diary: summary.diary,
                    highlights: summary.highlights,
                    toneRawValue: summary.toneRawValue,
                    confidence: summary.confidence
                )
            }
            
            // SwiftData에 저장
            if let context = modelContext {
                context.insert(route)
                try? context.save()
            }
            
            completedRoute = route
            progress = 1.0
        } catch {
            errorMessage = "경로 생성에 실패했습니다: \(error.localizedDescription)"
            showingError = true
        }
    }

    func cancelAnalysis() {
        isCancelled = true
    }

    private func resetProgressForNewRun() {
        isCancelled = false
        progress = 0
        processedCount = 0
        currentStep = .metadata
        showingError = false
        errorMessage = ""
        completedRoute = nil
    }
    
    // 메타데이터를 보존하면서 이미지 압축
    private func compressImageWithMetadataPreservation(originalData: Data, maxSize: Int) async -> Data? {
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil),
              let imageType = CGImageSourceGetType(source),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        // 원본 메타데이터 가져오기
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        // 압축 옵션 설정
        var compressionQuality: CGFloat = 0.8
        var compressedData: Data?
        
        // 목표 크기에 맞춰 품질 조정
        for _ in 0..<5 {
            let mutableData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                mutableData as CFMutableData,
                imageType,
                1,
                nil
            ) else {
                break
            }
            
            // 메타데이터와 함께 이미지 추가 (올바른 방법)
            var options = properties as [String: Any]
            options[kCGImageDestinationLossyCompressionQuality as String] = compressionQuality
            
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            
            guard CGImageDestinationFinalize(destination) else {
                break
            }
            
            compressedData = mutableData as Data
            
            if let data = compressedData, data.count <= maxSize {
                break
            }
            
            compressionQuality -= 0.1
        }
        
        return compressedData ?? originalData
    }
}
