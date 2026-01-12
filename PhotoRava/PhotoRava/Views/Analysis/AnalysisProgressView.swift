//
//  AnalysisProgressView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData

struct AnalysisProgressView: View {
    let photos: [LoadedPhoto]
    @StateObject private var viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingMapView = false
    
    init(photos: [LoadedPhoto]) {
        self.photos = photos
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(photos: photos))
    }
    
    var body: some View {
        ZStack {
            // Blurred background
            backgroundView
            
            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text(viewModel.currentStep)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("위치 데이터를 정제하고 있습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Circular Progress
                circularProgressView
                
                // Linear Progress
                linearProgressView
                
                // Description
                Text("잠시만 기다려 주세요. 사진의 메타데이터를 활용하여 상세 경로를 생성하고 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
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
            .padding()
        }
        .overlay(alignment: .bottom) {
            statusIndicator
        }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.startAnalysis()
        }
        .onChange(of: viewModel.completedRoute) { _, newRoute in
            if newRoute != nil {
                // 분석 완료 후 지도 화면으로 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingMapView = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingMapView) {
            if let route = viewModel.completedRoute {
                NavigationStack {
                    RouteMapView(route: route)
                }
            }
        }
        .alert("분석 오류", isPresented: $viewModel.showingError) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text(viewModel.errorMessage)
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
                .frame(width: 200, height: 200)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    Color.primaryBlue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            
            // Text
            VStack(spacing: 4) {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                Text("PROCESSING")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryBlue)
                    .tracking(1.5)
            }
            
            // Pulse animation
            Circle()
                .stroke(Color.primaryBlue.opacity(0.3), lineWidth: 2)
                .frame(width: 220, height: 220)
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
            HStack {
                Text("\(viewModel.processedCount)/\(viewModel.totalCount) 사진 처리 완료")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
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
            
            Text("SYNCING WITH CLOUD")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 40)
    }
}

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var processedCount: Int = 0
    @Published var currentStep: String = "도로명 인식 중..."
    @Published var isPulsing: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var completedRoute: Route?
    
    let photos: [LoadedPhoto]
    var totalCount: Int { photos.count }
    
    private let ocrService = OCRService()
    private let metadataService = PhotoMetadataService()
    private var isCancelled = false
    var modelContext: ModelContext?
    
    init(photos: [LoadedPhoto]) {
        self.photos = photos
    }
    
    func startAnalysis() async {
        var photoRecords: [PhotoRecord] = []
        
        // Step 1: 메타데이터 추출 및 시간순 정렬
        currentStep = "사진 정렬 중..."
        
        var photosWithMetadata: [(photo: LoadedPhoto, metadata: PhotoMetadata)] = []
        
        for photo in photos {
            guard !isCancelled else { break }
            
            let metadata = await metadataService.extractMetadata(from: photo.image, asset: photo.asset)
            photosWithMetadata.append((photo, metadata))
        }
        
        // 촬영 시간순 정렬
        photosWithMetadata.sort { $0.metadata.capturedAt < $1.metadata.capturedAt }
        
        // Step 2: OCR 실행
        currentStep = "도로명 인식 중..."
        
        for (index, item) in photosWithMetadata.enumerated() {
            guard !isCancelled else { break }
            
            let photo = item.photo
            let metadata = item.metadata
            
            // OCR 실행
            var roadName: String?
            var confidence: Float = 0
            
            do {
                let recognizedTexts = try await ocrService.recognizeText(in: photo.image)
                
                // 가장 신뢰도 높은 도로명 선택
                if let best = recognizedTexts.max(by: { $0.confidence < $1.confidence }) {
                    roadName = best.text
                    confidence = best.confidence
                }
            } catch {
                print("OCR failed for photo \(index): \(error)")
            }
            
            // PhotoRecord 생성
            let record = PhotoRecord(capturedAt: metadata.capturedAt)
            record.imageData = photo.image.jpegData(compressionQuality: 0.7)
            record.roadName = roadName
            record.ocrConfidence = confidence
            record.latitude = metadata.coordinate?.latitude
            record.longitude = metadata.coordinate?.longitude
            
            photoRecords.append(record)
            
            // 진행률 업데이트
            processedCount = index + 1
            progress = Double(processedCount) / Double(totalCount)
            
            // UI 업데이트를 위한 짧은 딜레이
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        guard !isCancelled else { return }
        
        // Step 3: 경로 재구성
        currentStep = "경로 생성 중..."
        
        do {
            let route = try await RouteReconstructionService.shared.reconstructRoute(from: photoRecords)
            
            // SwiftData에 저장
            if let context = modelContext {
                context.insert(route)
                try? context.save()
            }
            
            completedRoute = route
        } catch {
            errorMessage = "경로 생성에 실패했습니다: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func cancelAnalysis() {
        isCancelled = true
    }
}

