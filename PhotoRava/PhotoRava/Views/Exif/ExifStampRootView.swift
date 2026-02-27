//
//  ExifStampRootView.swift
//  PhotoRava
//
//  Created by Codex on 1/27/26.
//

import SwiftUI
import PhotosUI
import Photos
import UIKit
import UniformTypeIdentifiers
import ImageIO

struct ExifStampScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ExifStampRootView: View {
    @StateObject private var viewModel = ExifStampViewModel()
    @State private var selectedTab: ExifStampTab = .layout
    @State private var lastBatchPreviewIdentifier: String?
    @State private var showingFullScreenPreview = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    if viewModel.originalImage != nil {
                        TabView(selection: $selectedTab) {
                            ExifStampLayoutTab(viewModel: viewModel, showingFullScreenPreview: $showingFullScreenPreview)
                                .tabItem { Label("프레임", systemImage: "rectangle.inset.filled") }
                                .tag(ExifStampTab.layout)

                            ExifStampThemeTab(viewModel: viewModel, showingFullScreenPreview: $showingFullScreenPreview)
                                .tabItem { Label("테마", systemImage: "paintpalette") }
                                .tag(ExifStampTab.theme)

                            ExifStampExportTab(viewModel: viewModel, showingFullScreenPreview: $showingFullScreenPreview)
                                .tabItem { Label("내보내기", systemImage: "square.and.arrow.up") }
                                .tag(ExifStampTab.export)
                        }
                    } else {
                        emptyStateView
                    }
                }
            }
            .navigationTitle("EXIF")
            .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                PhotosPicker(
                                    selection: $viewModel.selectedItem,
                                    matching: .images
                                ) {
                                    Image(systemName: "photo.badge.plus")
                                }
                                .disabled(viewModel.isProcessing)
                            }
            
                            ToolbarItem(placement: .topBarTrailing) {                    PhotosPicker(
                        selection: $viewModel.batchSelectedItems,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    .disabled(viewModel.isProcessing || viewModel.batchExportState.isRunning)
                }
            }
            .overlay(alignment: .top) {
                if viewModel.isProcessing {
                    ProgressView("처리 중…")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 12)
                } else if viewModel.batchExportState.isRunning {
                    HStack(spacing: 10) {
                        ProgressView(value: viewModel.batchExportState.progressFraction)
                            .frame(width: 140)
                        Text("\(viewModel.batchExportState.completed + viewModel.batchExportState.failed)/\(viewModel.batchExportState.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("취소", role: .cancel) {
                            viewModel.cancelBatchExport()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 12)
                }
            }
            .alert("오류", isPresented: $viewModel.showingError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: viewModel.selectedItem) { _, _ in
                Task { await viewModel.loadSelectedPhoto() }
            }
            .onChange(of: viewModel.batchSelectedItems) { _, newValue in
                guard let first = newValue.first else { return }
                let id = first.itemIdentifier ?? UUID().uuidString
                guard lastBatchPreviewIdentifier != id else { return }
                lastBatchPreviewIdentifier = id
                viewModel.selectedItem = first
            }
            .fullScreenCover(isPresented: $showingFullScreenPreview) {
                ExifStampFullScreenPreview(image: viewModel.renderedImage)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "text.below.photo")
                    .font(.system(size: 50))
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 8) {
                Text("EXIF 문구 새기기")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("사진에 패딩을 추가하고\n카메라/노출 정보 등을 하단에 새깁니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $viewModel.selectedItem,
                    matching: .images
                ) {
                    Text("사진 선택")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 50)
                        .background(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isProcessing)

                PhotosPicker(
                    selection: $viewModel.batchSelectedItems,
                    matching: .images
                ) {
                    Text("여러 장 선택")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 200, height: 50)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isProcessing || viewModel.batchExportState.isRunning)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum ExifStampTab: Hashable {
    case layout
    case theme
    case export
}

enum ExifStampExportTarget: String, CaseIterable, Identifiable {
    case single
    case batch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: return "단일"
        case .batch: return "일괄"
        }
    }
}

private struct ExifStampFullScreenPreview: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .containerRelativeFrame(.horizontal)
                    }
                    .defaultScrollAnchor(.center)
                }
            }
            .navigationTitle("원본 미리보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ExifStampCropView: View {
    let image: UIImage
    @Binding var cropRect: CGRect?
    @Environment(\.dismiss) private var dismiss
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    
    // Ratios: Width / Height
    @State private var currentRatio: CGFloat? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    GeometryReader { geo in
                        let containerSize = geo.size
                        
                        // Main Image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .background(GeometryReader { imgGeo in
                                Color.clear.onAppear {
                                    // Could store image intrinsic layout if needed
                                }
                            })
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        
                        // Crop Window (Overlay)
                        let ratio = currentRatio ?? (image.size.width / image.size.height)
                        let cropW = min(containerSize.width * 0.8, containerSize.height * 0.8 * ratio)
                        let cropH = cropW / ratio
                        
                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropW, height: cropH)
                            .position(x: containerSize.width / 2, y: containerSize.height / 2)
                            .shadow(color: .black.opacity(0.5), radius: 10)
                            .allowsHitTesting(false)
                        
                        // Instruction
                        VStack {
                            Spacer()
                            Text("두 손가락으로 확대하고 드래그하여 맞추세요")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.6))
                                .clipShape(Capsule())
                                .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Aspect Ratio Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        RatioButton(label: "원본", current: $currentRatio, ratio: nil)
                        RatioButton(label: "1:1", current: $currentRatio, ratio: 1.0)
                        RatioButton(label: "4:5", current: $currentRatio, ratio: 4.0/5.0)
                        RatioButton(label: "5:4", current: $currentRatio, ratio: 5.0/4.0)
                        RatioButton(label: "3:2", current: $currentRatio, ratio: 3.0/2.0)
                        RatioButton(label: "16:9", current: $currentRatio, ratio: 16.0/9.0)
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("이미지 자르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        calculateAndApplyCrop(imageSize: image.size)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func calculateAndApplyCrop(imageSize: CGSize) {
        // We need the container size to do the math. 
        // For simplicity in this implementation, we use a fixed estimation or 
        // ideally we would have captured the GeometryProxy.
        // Let's use a standard screen-based estimation for now:
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height - 200 // Approx container height
        
        let containerSize = CGSize(width: screenWidth, height: screenHeight)
        
        // 1. Calculate the base fitted size of the image in the container (scaledToFit)
        let hRatio = containerSize.width / imageSize.width
        let vRatio = containerSize.height / imageSize.height
        let baseFitRatio = min(hRatio, vRatio)
        let fittedSize = CGSize(width: imageSize.width * baseFitRatio, height: imageSize.height * baseFitRatio)
        
        // 2. Current displayed size after scale
        let displayedSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)
        
        // 3. Crop Window Size
        let ratio = currentRatio ?? (imageSize.width / imageSize.height)
        let cropW = min(containerSize.width * 0.8, containerSize.height * 0.8 * ratio)
        let cropH = cropW / ratio
        
        // 4. Calculate relative offset of the crop window from the image center
        // Center of image in container is (screenWidth/2 + offset.width, screenHeight/2 + offset.height)
        // Center of crop window is (screenWidth/2, screenHeight/2)
        // Relative to image center, crop window center is at (-offset.width, -offset.height)
        
        // 5. Convert to normalized CGRect (0.0 to 1.0)
        let normCropW = cropW / displayedSize.width
        let normCropH = cropH / displayedSize.height
        
        let normX = (1.0 - normCropW) / 2 - (offset.width / displayedSize.width)
        let normY = (1.0 - normCropH) / 2 - (offset.height / displayedSize.height)
        
        cropRect = CGRect(x: normX, y: normY, width: normCropW, height: normCropH)
    }
    
    struct RatioButton: View {
        let label: String
        @Binding var current: CGFloat?
        let ratio: CGFloat?
        
        var body: some View {
            Button {
                current = ratio
            } label: {
                Text(label)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(current == ratio ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(current == ratio ? .white : .primary)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct ExifStampPreviewCard: View {
    let image: UIImage?
    let isRendering: Bool
    @Binding var showingFullScreen: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .frame(height: 240)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
            }

            if let _ = image, !isRendering {
                Button {
                    showingFullScreen = true
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary)
                        .background(Circle().fill(.ultraThinMaterial))
                        .padding(8)
                }
            }

            if isRendering {
                ProgressView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

private struct ExifStampOptionsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

private struct ExifStampLayoutTab: View {
    @ObservedObject var viewModel: ExifStampViewModel
    @Binding var showingFullScreenPreview: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var showingCropView: Bool = false
    @State private var tempTextScale: Double = 1.0
    @State private var tempPaddingTop: Double = 0
    @State private var tempPaddingBottom: Double = 0
    @State private var tempPaddingLeft: Double = 0
    @State private var tempPaddingRight: Double = 0

    private var previewScale: CGFloat {
        if scrollOffset <= 0 { return 1.0 }
        let scale = 1.0 - (scrollOffset / 350) // 더 빨리 작아지게 변경
        return max(0.25, scale) // 최소 크기를 0.25로 더 축소
    }

    private var previewOffset: CGSize {
        if scrollOffset <= 0 { return .zero }
        // 우측 상단으로 더 바짝 붙도록 오프셋 조정
        let x = scrollOffset * 0.5
        let y = -scrollOffset * 0.05
        return CGSize(width: min(x, 150), height: max(y, -40))
    }

    private var previewOpacity: Double {
        if scrollOffset <= 50 { return 1.0 }
        let opacity = 1.0 - (scrollOffset / 1000)
        return max(0.7, opacity) // 스크롤 시 약간 투명하게
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    // Placeholder for the preview card to keep its space when large
                    Color.clear
                        .frame(height: 300)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ExifStampScrollOffsetKey.self, value: -geo.frame(in: .named("scroll")).minY)
                        })

                    if viewModel.exportTarget == .batch, viewModel.batchSelectionCount > 0 {
                        layoutBatchPreviewStrip
                            .padding(.horizontal)
                    }

                    ExifStampOptionsCard(title: "프레임/레이아웃") {
                        if let img = viewModel.originalImage {
                            Button {
                                showingCropView = true
                            } label: {
                                Label(viewModel.cropRectBinding.wrappedValue == nil ? "이미지 자르기" : "자르기 수정 (이미 적용됨)", systemImage: "crop")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.cropRectBinding.wrappedValue == nil ? .accentColor : .green)
                            .sheet(isPresented: $showingCropView) {
                                ExifStampCropView(image: img, cropRect: viewModel.cropRectBinding)
                            }
                            
                            if viewModel.cropRectBinding.wrappedValue != nil {
                                Button(role: .destructive) {
                                    viewModel.cropRectBinding.wrappedValue = nil
                                } label: {
                                    Text("자르기 초기화")
                                        .font(.caption)
                                }
                                .padding(.top, -8)
                            }
                        }

                        HStack {
                            Text("레이아웃")
                            Spacer()
                            Text(viewModel.currentTheme.layout.label)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("최종 비율 (캔버스)")
                            Spacer()
                            Picker("최종 비율", selection: viewModel.canvasRatioBinding) {
                                ForEach(ExifStampCanvasRatio.allCases) { ratio in
                                    Text(ratio.label).tag(ratio)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if viewModel.currentTheme.customizationSchema.allowsPaddingPreset {
                            HStack {
                                Text("패딩")
                                Spacer()
                                Picker("패딩", selection: viewModel.paddingPresetBinding) {
                                    ForEach(ExifStampPaddingPreset.allCases) { p in
                                        Text(p.label).tag(p)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        if viewModel.currentTheme.customizationSchema.allowsAdvancedPadding {
                            Toggle("고급 패딩", isOn: viewModel.advancedPaddingEnabledBinding)

                        if viewModel.advancedPaddingEnabledBinding.wrappedValue {
                            VStack(spacing: 10) {
                                paddingSlider(label: "상", binding: $tempPaddingTop) { viewModel.paddingTopBinding.wrappedValue = $0 }
                                paddingSlider(label: "하", binding: $tempPaddingBottom) { viewModel.paddingBottomBinding.wrappedValue = $0 }
                                paddingSlider(label: "좌", binding: $tempPaddingLeft) { viewModel.paddingLeftBinding.wrappedValue = $0 }
                                paddingSlider(label: "우", binding: $tempPaddingRight) { viewModel.paddingRightBinding.wrappedValue = $0 }
                            }
                            .padding(.top, 4)
                        }
                        }

                        if viewModel.currentTheme.customizationSchema.allowsTextAlignment {
                            HStack {
                                Text("정렬")
                                Spacer()
                                Picker("정렬", selection: viewModel.textAlignmentBinding) {
                                    ForEach(ExifStampTextAlignment.allCases) { a in
                                        Text(a.label).tag(a)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                            }
                        }

                        if viewModel.currentTheme.customizationSchema.allowsTextScale {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("문구 크기")
                                    Spacer()
                                    Text("\(Int((tempTextScale * 100).rounded()))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: $tempTextScale,
                                    in: 0.0...2.0,
                                    step: 0.05,
                                    onEditingChanged: { editing in
                                        if !editing {
                                            viewModel.textScaleBinding.wrappedValue = tempTextScale
                                        }
                                    }
                                )
                            }
                        }

                        if let line1 = viewModel.captionLines.line1 ?? viewModel.captionLines.line2 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("문구 미리보기")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(line1)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.currentTheme.layout.supportsCaption {
                        ExifStampOptionsCard(title: "표시 항목") {
                            Toggle("제조사", isOn: viewModel.showsMakeBinding)
                            Toggle("바디 모델", isOn: viewModel.showsModelBinding)
                            Toggle("렌즈", isOn: viewModel.showsLensBinding)
                            Toggle("ISO", isOn: viewModel.showsISOBinding)
                            Toggle("셔터", isOn: viewModel.showsShutterBinding)
                            Toggle("f값", isOn: viewModel.showsFNumberBinding)
                            Toggle("초점거리", isOn: viewModel.showsFocalLengthBinding)
                            Toggle("날짜", isOn: viewModel.showsDateBinding)

                            if viewModel.showsDateBinding.wrappedValue {
                                HStack {
                                    Text("날짜 포맷")
                                    Spacer()
                                    Picker("날짜 포맷", selection: viewModel.dateFormatPresetBinding) {
                                        ForEach(ExifStampDateFormatPreset.allCases) { p in
                                            Text(p.label).tag(p)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 12)
                }
                .padding(.vertical)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ExifStampScrollOffsetKey.self) { offset in
                scrollOffset = offset
            }

            // Sticky Preview Card
            ExifStampPreviewCard(
                image: viewModel.renderedImage,
                isRendering: viewModel.isRendering,
                showingFullScreen: $showingFullScreenPreview
            )
            .scaleEffect(previewScale, anchor: .topTrailing)
            .opacity(previewOpacity)
            .offset(previewOffset)
            .frame(height: 300) // Match the placeholder height
            .zIndex(1)
            .allowsHitTesting(previewScale > 0.5) // 너무 작아지면 클릭 방해 방지 (필요 시)
        }
        .onAppear {
            syncTempsFromViewModel()
        }
        .onChange(of: viewModel.currentTheme.id) { _, _ in
            syncTempsFromViewModel()
        }
        .onChange(of: viewModel.advancedPaddingEnabledBinding.wrappedValue) { _, _ in
            syncTempsFromViewModel()
        }
    }

    private func paddingSlider(label: String, binding: Binding<Double>, onCommit: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("패딩 \(label)")
                Spacer()
                Text("\(Int((binding.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: binding,
                in: 0...0.25,
                step: 0.005,
                onEditingChanged: { editing in
                    if !editing {
                        onCommit(binding.wrappedValue)
                    }
                }
            )
        }
    }

    private func syncTempsFromViewModel() {
        tempTextScale = viewModel.textScaleBinding.wrappedValue
        tempPaddingTop = viewModel.paddingTopBinding.wrappedValue
        tempPaddingBottom = viewModel.paddingBottomBinding.wrappedValue
        tempPaddingLeft = viewModel.paddingLeftBinding.wrappedValue
        tempPaddingRight = viewModel.paddingRightBinding.wrappedValue
    }

    private var layoutBatchPreviewStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("사진 선택")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.batchSelectionCount)장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.batchSources.enumerated()), id: \.element.identifier) { _, source in
                        Button {
                            Task { await viewModel.loadBatchPreviewSource(source) }
                        } label: {
                            ZStack {
                                if let image = viewModel.thumbnailCache[source.identifier] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.secondarySystemBackground))
                                    ProgressView()
                                }

                                // 크롭 적용 배지
                                if viewModel.hasCropApplied(for: source.identifier) {
                                    Image(systemName: "crop")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                        .padding(4)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.activePhotoIdentifier == source.identifier ? Color.primary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .task(id: source.identifier) {
                            _ = await viewModel.thumbnailImage(for: source)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

enum ExifStampColorPreset: String, CaseIterable, Identifiable {
    case white
    case black

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white: return "화이트"
        case .black: return "블랙"
        }
    }
}

private struct ExifStampThemeTab: View {
    @ObservedObject var viewModel: ExifStampViewModel
    @Binding var showingFullScreenPreview: Bool
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showingSettingsImporter = false

    private var previewScale: CGFloat {
        if scrollOffset <= 0 { return 1.0 }
        let scale = 1.0 - (scrollOffset / 350)
        return max(0.25, scale)
    }

    private var previewOffset: CGSize {
        if scrollOffset <= 0 { return .zero }
        let x = scrollOffset * 0.5
        let y = -scrollOffset * 0.05
        return CGSize(width: min(x, 150), height: max(y, -40))
    }

    private var previewOpacity: Double {
        if scrollOffset <= 50 { return 1.0 }
        let opacity = 1.0 - (scrollOffset / 1000)
        return max(0.7, opacity)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    // Placeholder
                    Color.clear
                        .frame(height: 300)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ExifStampScrollOffsetKey.self, value: -geo.frame(in: .named("scroll")).minY)
                        })

                    ExifStampOptionsCard(title: "테마") {
                        ForEach(ExifStampTheme.builtInThemes) { theme in
                            Button {
                                viewModel.selectTheme(theme.id)
                            } label: {
                                HStack {
                                    Text(theme.displayName)
                                    Spacer()
                                    if viewModel.currentTheme.id == theme.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.horizontal)

                    ExifStampOptionsCard(title: "커스터마이징") {
                        if viewModel.currentTheme.customizationSchema.allowsBackgroundColor {
                            HStack {
                                Text("배경")
                                Spacer()
                                Picker("배경", selection: viewModel.colorPresetBinding) {
                                    ForEach(ExifStampColorPreset.allCases) { preset in
                                        Text(preset.label).tag(preset)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                viewModel.resetCurrentThemeOverrides()
                            } label: {
                                Label("테마 리셋", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                viewModel.resetAllSettings()
                            } label: {
                                Label("전체 리셋", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 12) {
                            Button {
                                viewModel.shareSettingsJSON()
                            } label: {
                                Label("설정 내보내기", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showingSettingsImporter = true
                            } label: {
                                Label("설정 가져오기", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                    .fileImporter(
                        isPresented: $showingSettingsImporter,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            viewModel.importSettingsJSON(from: url)
                        case .failure(let error):
                            viewModel.showImportExportError(error.localizedDescription)
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(.vertical)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ExifStampScrollOffsetKey.self) { offset in
                scrollOffset = offset
            }

            // Sticky Preview Card
            ExifStampPreviewCard(
                image: viewModel.renderedImage,
                isRendering: viewModel.isRendering,
                showingFullScreen: $showingFullScreenPreview
            )
            .scaleEffect(previewScale, anchor: .topTrailing)
            .opacity(previewOpacity)
            .offset(previewOffset)
            .frame(height: 300)
            .zIndex(1)
            .allowsHitTesting(previewScale > 0.5)
        }
    }
}

private struct ExifStampExportTab: View {
    @ObservedObject var viewModel: ExifStampViewModel
    @Binding var showingFullScreenPreview: Bool
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showBatchResults: Bool = false
    @State private var selectedBatchPreviewIdentifier: String?

    private var previewScale: CGFloat {
        if scrollOffset <= 0 { return 1.0 }
        let scale = 1.0 - (scrollOffset / 350)
        return max(0.25, scale)
    }

    private var previewOffset: CGSize {
        if scrollOffset <= 0 { return .zero }
        let x = scrollOffset * 0.5
        let y = -scrollOffset * 0.05
        return CGSize(width: min(x, 150), height: max(y, -40))
    }

    private var previewOpacity: Double {
        if scrollOffset <= 50 { return 1.0 }
        let opacity = 1.0 - (scrollOffset / 1000)
        return max(0.7, opacity)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    // Placeholder
                    Color.clear
                        .frame(height: 300)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ExifStampScrollOffsetKey.self, value: -geo.frame(in: .named("scroll")).minY)
                        })

                    if viewModel.exportTarget == .batch, viewModel.batchSelectionCount > 0 {
                        batchPreviewStrip
                            .padding(.horizontal)
                    }

                    ExifStampOptionsCard(title: "내보내기") {
                        HStack {
                            Text("내보내기 대상")
                            Spacer()
                            Picker("내보내기 대상", selection: $viewModel.exportTarget) {
                                ForEach(ExifStampExportTarget.allCases) { t in
                                    Text(t.label).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        .disabled(viewModel.batchExportState.isRunning && viewModel.exportTarget == .batch)

                        if viewModel.exportTarget == .batch {
                            HStack {
                                Text("선택된 사진")
                                Spacer()
                                Text("\(viewModel.batchSelectionCount)장")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if viewModel.exportTarget == .batch {
                            HStack {
                                Text("동시 처리")
                                Spacer()
                                Picker("동시 처리", selection: viewModel.batchConcurrencyLimitBinding) {
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            }
                            .disabled(viewModel.batchExportState.isRunning)
                        }

                        if viewModel.exportTarget == .batch {
                            Text("배치 공유는 선택된 파일들을 여러 개로 공유합니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("포맷")
                            Spacer()
                            Picker("포맷", selection: viewModel.exportFormatBinding) {
                                ForEach(ExifStampExportFormat.allCases) { f in
                                    Text(f.label).tag(f)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .disabled(viewModel.batchExportState.isRunning && viewModel.exportTarget == .batch)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(viewModel.exportFormatBinding.wrappedValue == .heic ? "HEIC 품질" : "JPEG 품질")
                                Spacer()
                                Text("\(Int((viewModel.jpegQualityBinding.wrappedValue * 100).rounded()))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: viewModel.jpegQualityBinding, in: 0.2...1.0, step: 0.01)
                        }
                        .opacity(viewModel.exportFormatBinding.wrappedValue.supportsQuality ? 1.0 : 0.35)
                        .disabled(!viewModel.exportFormatBinding.wrappedValue.supportsQuality || (viewModel.batchExportState.isRunning && viewModel.exportTarget == .batch))

                        Toggle("EXIF 유지(가능한 경우)", isOn: viewModel.keepExifBinding)
                            .disabled((viewModel.exportTarget == .single && viewModel.originalImageData == nil) || (viewModel.batchExportState.isRunning && viewModel.exportTarget == .batch))

                        if viewModel.exportTarget == .single, viewModel.originalImageData == nil {
                            Text("이 사진은 원본 데이터 접근이 불가해 EXIF 유지가 적용되지 않습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if viewModel.exportTarget == .batch, viewModel.keepExifBinding.wrappedValue {
                            Text("일부 사진은 원본 데이터 접근이 불가해 EXIF 유지가 적용되지 않을 수 있습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("출력 해상도")
                            Spacer()
                            Picker("출력 해상도", selection: viewModel.exportSizeBinding) {
                                ForEach(ExifStampExportSize.allCases) { size in
                                    Text(size.label).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .disabled(viewModel.batchExportState.isRunning && viewModel.exportTarget == .batch)

                        if viewModel.exportTarget == .batch, viewModel.batchExportState.isRunning {
                            VStack(alignment: .leading, spacing: 10) {
                                ProgressView(value: viewModel.batchExportState.progressFraction) {
                                    Text("진행 \(viewModel.batchExportState.completed + viewModel.batchExportState.failed)/\(viewModel.batchExportState.total)")
                                }
                                .progressViewStyle(.linear)

                                HStack(spacing: 12) {
                                    Text("처리 중: \(max(0, viewModel.batchExportState.currentIndex))/\(viewModel.batchExportState.total)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("취소", role: .cancel) {
                                        viewModel.cancelBatchExport()
                                    }
                                }
                            }
                            .padding(.top, 6)
                        }

                        if viewModel.exportTarget == .batch, let summary = viewModel.batchExportState.lastSummary {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    Task {
                                        await viewModel.preparePhotosForRouteAnalysis()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("이 사진들로 경로 분석하기")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .padding(.top, 4)
                            }
                        }

                        if viewModel.exportTarget == .batch, !viewModel.batchExportState.lastFailures.isEmpty {
                            DisclosureGroup("실패 내역 (\(viewModel.batchExportState.failed)건)") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(viewModel.batchExportState.lastFailures.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        if viewModel.exportTarget == .batch, !viewModel.batchExportState.results.isEmpty {
                            DisclosureGroup("결과 보기", isExpanded: $showBatchResults) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.batchExportState.results) { r in
                                        HStack(spacing: 10) {
                                            Text(String(format: "%03d", r.index + 1))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 44, alignment: .leading)
                                            Text(resultLabel(for: r.status))
                                                .font(.caption)
                                                .foregroundStyle(r.status == .failed ? .red : .secondary)
                                            if let message = r.message, r.status == .failed {
                                                Text(message)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }

                        if viewModel.exportTarget == .batch, viewModel.canRetryLastBatch, !viewModel.batchExportState.isRunning {
                            Button("실패 항목 재시도") {
                                viewModel.retryFailedBatch()
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 12) {
                            if viewModel.exportTarget == .single {
                                Button {
                                    viewModel.shareRendered()
                                } label: {
                                    Label("공유", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                                .buttonStyle(.bordered)
                                .tint(.primary)
                                .disabled(viewModel.renderedImage == nil)

                                Button {
                                    Task { await viewModel.saveRenderedToPhotos() }
                                } label: {
                                    Label("저장", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.renderedImage == nil || viewModel.isProcessing)
                            } else {
                                Button {
                                    viewModel.startBatchShare()
                                } label: {
                                    Label("공유", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                                .buttonStyle(.bordered)
                                .tint(.primary)
                                .disabled(viewModel.batchSelectionCount == 0 || viewModel.batchExportState.isRunning)

                                Button {
                                    viewModel.startBatchSaveToPhotos()
                                } label: {
                                    Label("저장", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.batchSelectionCount == 0 || viewModel.batchExportState.isRunning)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 12)
                }
                .padding(.vertical)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ExifStampScrollOffsetKey.self) { offset in
                scrollOffset = offset
            }

            // Sticky Preview Card
            ExifStampPreviewCard(
                image: viewModel.renderedImage,
                isRendering: viewModel.isRendering,
                showingFullScreen: $showingFullScreenPreview
            )
            .scaleEffect(previewScale, anchor: .topTrailing)
            .opacity(previewOpacity)
            .offset(previewOffset)
            .frame(height: 300)
            .zIndex(1)
            .allowsHitTesting(previewScale > 0.5)
        }
        .onAppear {
            syncSelectedBatchPreviewIfNeeded()
        }
        .onChange(of: viewModel.exportTarget) { _, _ in
            syncSelectedBatchPreviewIfNeeded()
        }
        .onChange(of: viewModel.batchSelectionCount) { _, _ in
            syncSelectedBatchPreviewIfNeeded()
        }
        .alert("저장 완료", isPresented: $viewModel.showingAnalysisSuggestion) {
            Button("나중에") { }
            Button("경로 분석 시작") {
                Task {
                    await viewModel.preparePhotosForRouteAnalysis()
                }
            }
        } message: {
            Text("사진이 성공적으로 저장되었습니다. 이 사진들의 위치 정보를 사용하여 경로를 분석하시겠습니까?")
        }
    }

    private func resultLabel(for status: ExifStampBatchExportState.ResultItem.Status) -> String {
        switch status {
        case .pending: return "대기"
        case .success: return "성공"
        case .failed: return "실패"
        }
    }

    private func syncSelectedBatchPreviewIfNeeded() {
        guard viewModel.exportTarget == .batch else { return }
        guard !viewModel.batchSources.isEmpty else {
            selectedBatchPreviewIdentifier = nil
            return
        }
        let existing = selectedBatchPreviewIdentifier
        if let existing, viewModel.batchSources.contains(where: { $0.identifier == existing }) {
            return
        }
        let first = viewModel.batchSources[0]
        selectedBatchPreviewIdentifier = first.identifier
        Task { await viewModel.loadBatchPreviewSource(first) }
    }

    private var batchPreviewStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("프리뷰 선택")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.batchSelectionCount)장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.batchSources.enumerated()), id: \.element.identifier) { _, source in
                        Button {
                            selectedBatchPreviewIdentifier = source.identifier
                            Task { await viewModel.loadBatchPreviewSource(source) }
                        } label: {
                            ZStack {
                                if let image = viewModel.thumbnailCache[source.identifier] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                    ProgressView()
                                }

                                // 크롭 적용 배지
                                if viewModel.hasCropApplied(for: source.identifier) {
                                    Image(systemName: "crop")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                        .padding(4)
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedBatchPreviewIdentifier == source.identifier ? Color.primary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .task(id: source.identifier) {
                            _ = await viewModel.thumbnailImage(for: source)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

@MainActor
final class ExifStampViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem? {
        didSet { 
            guard let selectedItem else { return }
            
            // Update active photo identifier
            activePhotoIdentifier = selectedItem.itemIdentifier
            
            // 현재 선택된 아이템이 일괄 선택 목록에 포함되어 있는지 확인
            let isItemInBatch = batchSelectedItems.contains { $0.itemIdentifier == selectedItem.itemIdentifier }
            
            if !isItemInBatch {
                // 일괄 목록에 없는 새로운 아이템을 선택한 경우 (단일 선택 모드)
                if !batchSelectedItems.isEmpty {
                    batchSelectedItems = [] // 기존 일괄 목록 초기화
                }
                exportTarget = .single
            }
        }
    }
    @Published var batchSelectedItems: [PhotosPickerItem] = [] {
        didSet { 
            rebuildBatchSelection()
            // 여러 장이 선택되면 즉시 일괄 모드로 전환
            if !batchSelectedItems.isEmpty {
                exportTarget = .batch
            }
        }
    }
    @Published var isProcessing = false
    @Published var isRendering = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var batchExportState = ExifStampBatchExportState()
    @Published var showingAnalysisSuggestion = false
    @Published var exportTarget: ExifStampExportTarget = .single
    @Published private(set) var activePhotoIdentifier: String?

    @Published private(set) var originalImage: UIImage?
    @Published private(set) var originalImageData: Data?
    @Published private(set) var metadata = ExifStampMetadata()
    @Published private(set) var captionLines: (line1: String?, line2: String?) = (nil, nil)
    @Published private(set) var renderedImage: UIImage?
    
    private let metadataService = PhotoMetadataService()
    @Published private var userSettings: ExifStampUserSettings
    private var renderTask: Task<Void, Never>?
    private var renderGeneration: UInt = 0
    private var lastRenderedGeneration: UInt = 0
    private let renderCoordinator = RenderCoordinator()
    private var batchExportTask: Task<Void, Never>?
    private let batchExportQueue = DispatchQueue(label: "PhotoRava.ExifStampBatchExportQueue", qos: .userInitiated, attributes: .concurrent)
    @Published private(set) var batchSources: [BatchSource] = []
    @Published private(set) var thumbnailCache: [String: UIImage] = [:]
    private var lastBatchSources: [BatchSource] = []
    private var lastBatchSnapshot: BatchSnapshot?
    private var lastBatchMode: ExifStampBatchExportState.Mode?

    actor BatchShareURLCollector {
        private var urlsByIndex: [Int: URL] = [:]
        func set(_ url: URL, index: Int) { urlsByIndex[index] = url }
        func ordered() -> [URL] { urlsByIndex.keys.sorted().compactMap { urlsByIndex[$0] } }
    }

    enum BatchSource {
        case asset(PHAsset)
        case item(item: PhotosPickerItem, identifier: String)

        var identifier: String {
            switch self {
            case .asset(let asset): return asset.localIdentifier
            case .item(_, let identifier): return identifier
            }
        }
    }

    var batchSelectionCount: Int { batchSources.count }

    func hasCropApplied(for identifier: String) -> Bool {
        userSettings.photoOverridesById[identifier]?.cropRect != nil
    }

    var canRetryLastBatch: Bool {
        guard !batchExportState.isRunning else { return false }
        guard lastBatchSnapshot != nil, lastBatchMode != nil else { return false }
        guard !lastBatchSources.isEmpty else { return false }
        return batchExportState.results.contains(where: { $0.status == .failed })
    }

    func thumbnailImage(for source: BatchSource) async -> UIImage? {
        let id = source.identifier
        if let cached = thumbnailCache[id] { return cached }

        let image: UIImage?
        switch source {
        case .asset(let asset):
            image = await fetchThumbnailImage(for: asset, targetSize: CGSize(width: 600, height: 600))
        case .item(let item, _):
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let decoded = UIImage(data: data) else {
                return nil
            }
            image = decoded
        }

        if let image {
            thumbnailCache[id] = image
        }
        return image
    }

    func loadBatchPreviewSource(_ source: BatchSource) async {
        isProcessing = true
        defer { isProcessing = false }

        let id = source.identifier
        activePhotoIdentifier = id

        let asset: PHAsset?
        let data: Data?

        switch source {
        case .asset(let a):
            asset = a
            data = await metadataService.fetchOriginalImageData(for: a)
        case .item(let item, _):
            asset = nil
            data = try? await item.loadTransferable(type: Data.self)
        }

        let image: UIImage?
        if let data, let decoded = UIImage(data: data) {
            image = decoded
        } else if let asset {
            image = await fetchThumbnailImage(for: asset, targetSize: CGSize(width: 1600, height: 1600))
        } else {
            image = nil
        }

        guard let image else {
            showError("사진을 불러오지 못했습니다.")
            return
        }

        originalImage = image
        originalImageData = data
        if let data {
            metadata = ExifStampMetadataService.shared.extract(from: data, fallbackAsset: asset)
        } else {
            metadata = ExifStampMetadata(capturedAt: asset?.creationDate)
        }
        // 메인 스레드에서 즉시 렌더링 호출
        await MainActor.run {
            self.scheduleRender()
        }
    }

    private struct RenderRequest {
        var generation: UInt
        var originalImage: UIImage
        var spec: ExifStampRenderSpec
        var lines: (line1: String?, line2: String?)
    }

    private final class RenderCoordinator: @unchecked Sendable {
        private let queue = DispatchQueue(label: "PhotoRava.ExifStampRenderQueue", qos: .userInitiated)
        private var isRunning = false
        private var pending: RenderRequest?

        func enqueue(_ request: RenderRequest, completion: @escaping (UInt, UIImage) -> Void) {
            queue.async {
                self.pending = request
                if self.isRunning { return }
                self.isRunning = true

                while let next = self.pending {
                    self.pending = nil
                    let image: UIImage = autoreleasepool {
                        StampedImageRenderer.shared.render(
                            originalImage: next.originalImage,
                            line1: next.lines.line1,
                            line2: next.lines.line2,
                            spec: next.spec
                        )
                    }

                    DispatchQueue.main.async { completion(next.generation, image) }
                }

                self.isRunning = false
            }
        }
    }
    
    init() {
        self.userSettings = ExifStampUserSettingsPersistence.load()
        rebuildBatchSelection()
    }

    var currentTheme: ExifStampTheme {
        ExifStampTheme.theme(for: userSettings.selectedThemeId)
    }

    var paddingPresetBinding: Binding<ExifStampPaddingPreset> {
        Binding(
            get: { [weak self] in self?.effectivePaddingPreset() ?? .medium },
            set: { [weak self] newValue in
                self?.updateOverride { $0.paddingPreset = newValue }
            }
        )
    }

    var advancedPaddingEnabledBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in
                guard let self else { return false }
                let o = self.currentOverride()
                return o.paddingTopFraction != nil
                    || o.paddingBottomFraction != nil
                    || o.paddingLeftFraction != nil
                    || o.paddingRightFraction != nil
            },
            set: { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    let base = self.effectivePaddingPreset().baseFraction
                    self.updateOverride {
                        $0.paddingTopFraction = $0.paddingTopFraction ?? base
                        $0.paddingBottomFraction = $0.paddingBottomFraction ?? base
                        $0.paddingLeftFraction = $0.paddingLeftFraction ?? base
                        $0.paddingRightFraction = $0.paddingRightFraction ?? base
                    }
                } else {
                    self.updateOverride {
                        $0.paddingTopFraction = nil
                        $0.paddingBottomFraction = nil
                        $0.paddingLeftFraction = nil
                        $0.paddingRightFraction = nil
                    }
                }
            }
        )
    }

    var paddingTopBinding: Binding<Double> { paddingEdgeBinding(get: { $0.paddingTopFraction }, set: { $0.paddingTopFraction = $1 }) }
    var paddingBottomBinding: Binding<Double> { paddingEdgeBinding(get: { $0.paddingBottomFraction }, set: { $0.paddingBottomFraction = $1 }) }
    var paddingLeftBinding: Binding<Double> { paddingEdgeBinding(get: { $0.paddingLeftFraction }, set: { $0.paddingLeftFraction = $1 }) }
    var paddingRightBinding: Binding<Double> { paddingEdgeBinding(get: { $0.paddingRightFraction }, set: { $0.paddingRightFraction = $1 }) }

    var textAlignmentBinding: Binding<ExifStampTextAlignment> {
        Binding(
            get: { [weak self] in self?.effectiveTextAlignment() ?? .center },
            set: { [weak self] newValue in
                self?.updateOverride { $0.textAlignment = newValue }
            }
        )
    }

    var textScaleBinding: Binding<Double> {
        Binding(
            get: { [weak self] in self?.effectiveTextScale() ?? 1.0 },
            set: { [weak self] newValue in
                self?.updateOverride { $0.textScale = newValue }
            }
        )
    }

    var colorPresetBinding: Binding<ExifStampColorPreset> {
        Binding(
            get: { [weak self] in
                guard let self else { return .white }
                let hex = self.effectiveBackgroundHex().uppercased()
                return (hex == "#000000FF" || hex == "#000000") ? .black : .white
            },
            set: { [weak self] preset in
                guard let self else { return }
                switch preset {
                case .white:
                    self.updateOverride {
                        $0.backgroundColorHex = "#FFFFFFFF"
                        $0.textColorHex = "#000000FF"
                    }
                case .black:
                    self.updateOverride {
                        $0.backgroundColorHex = "#000000FF"
                        $0.textColorHex = "#FFFFFFFF"
                    }
                }
            }
        )
    }

    var jpegQualityBinding: Binding<Double> {
        Binding(
            get: { [weak self] in self?.userSettings.exportSettings.jpegQuality ?? 0.9 },
            set: { [weak self] newValue in
                guard let self else { return }
                self.userSettings.exportSettings.jpegQuality = newValue
                self.persistSettings()
            }
        )
    }

    var exportSizeBinding: Binding<ExifStampExportSize> {
        Binding(
            get: { [weak self] in self?.userSettings.exportSettings.exportSize ?? .original },
            set: { [weak self] newValue in
                guard let self else { return }
                self.userSettings.exportSettings.exportSize = newValue
                self.persistSettings()
                self.scheduleRender()
            }
        )
    }

    var cropRectBinding: Binding<CGRect?> {
        Binding(
            get: { [weak self] in self?.currentOverride().cropRect },
            set: { [weak self] newValue in
                self?.updateOverride { $0.cropRect = newValue }
            }
        )
    }

    var canvasRatioBinding: Binding<ExifStampCanvasRatio> {
        Binding(
            get: { [weak self] in
                guard let self else { return .original }
                return self.currentOverride().canvasRatio ?? self.currentTheme.defaults.canvasRatio
            },
            set: { [weak self] newValue in
                self?.updateOverride { $0.canvasRatio = newValue }
            }
        )
    }

    var exportFormatBinding: Binding<ExifStampExportFormat> {
        Binding(
            get: { [weak self] in self?.userSettings.exportSettings.format ?? .jpeg },
            set: { [weak self] newValue in
                guard let self else { return }
                self.userSettings.exportSettings.format = newValue
                self.persistSettings()
            }
        )
    }

    var keepExifBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.userSettings.exportSettings.keepExif ?? false },
            set: { [weak self] newValue in
                guard let self else { return }
                self.userSettings.exportSettings.keepExif = newValue
                self.persistSettings()
            }
        )
    }

    var batchConcurrencyLimitBinding: Binding<Int> {
        Binding(
            get: { [weak self] in
                guard let self else { return 1 }
                let v = self.userSettings.exportSettings.batchConcurrencyLimit
                return max(1, min(2, v))
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.userSettings.exportSettings.batchConcurrencyLimit = max(1, min(2, newValue))
                self.persistSettings()
            }
        )
    }

    var showsMakeBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsMake }, get: { $0.showsMake }, set: { $0.showsMake = $1 }) }
    var showsModelBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsModel }, get: { $0.showsModel }, set: { $0.showsModel = $1 }) }
    var showsLensBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsLens }, get: { $0.showsLens }, set: { $0.showsLens = $1 }) }
    var showsISOBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsISO }, get: { $0.showsISO }, set: { $0.showsISO = $1 }) }
    var showsShutterBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsShutter }, get: { $0.showsShutter }, set: { $0.showsShutter = $1 }) }
    var showsFNumberBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsFNumber }, get: { $0.showsFNumber }, set: { $0.showsFNumber = $1 }) }
    var showsFocalLengthBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsFocalLength }, get: { $0.showsFocalLength }, set: { $0.showsFocalLength = $1 }) }
    var showsDateBinding: Binding<Bool> { visibilityBinding(defaultValue: { $0.showsDate }, get: { $0.showsDate }, set: { $0.showsDate = $1 }) }

    var dateFormatPresetBinding: Binding<ExifStampDateFormatPreset> {
        Binding(
            get: { [weak self] in self?.effectiveDateFormatPreset() ?? .locale },
            set: { [weak self] newValue in
                self?.updateOverride { $0.dateFormatPreset = newValue }
            }
        )
    }

    func selectTheme(_ themeId: String) {
        userSettings.selectedThemeId = themeId
        persistSettings()
        scheduleRender()
    }

    func resetCurrentThemeOverrides() {
        userSettings.themeOverridesById[currentTheme.id] = nil
        persistSettings()
        scheduleRender()
    }

    func resetAllSettings() {
        userSettings = .default
        persistSettings()
        scheduleRender()
    }

    func loadSelectedPhoto() async {
        guard let selectedItem else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let identifier = selectedItem.itemIdentifier
            let asset: PHAsset? = {
                guard let identifier else { return nil }
                return PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
            }()
            
            let image: UIImage?
            if let asset {
                image = await fetchThumbnailImage(for: asset, targetSize: CGSize(width: 1600, height: 1600))
            } else if let data = try? await selectedItem.loadTransferable(type: Data.self) {
                image = UIImage(data: data)
            } else {
                image = nil
            }
            
            guard let image else {
                throw ExifStampError.failedToLoadImage
            }
            
            originalImage = image
            
            let data: Data?
            if let asset {
                data = await metadataService.fetchOriginalImageData(for: asset)
            } else {
                data = try? await selectedItem.loadTransferable(type: Data.self)
            }
            
            originalImageData = data
            
            if let data {
                metadata = ExifStampMetadataService.shared.extract(from: data, fallbackAsset: asset)
            } else {
                metadata = ExifStampMetadata(capturedAt: asset?.creationDate)
            }
            
            scheduleRender()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func scheduleRender() {
        renderTask?.cancel()
        renderGeneration &+= 1
        let generation = renderGeneration
        isRendering = (originalImage != nil)

        renderTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            await self?.renderNow(generation: generation)
        }
    }
    
    private func renderNow(generation: UInt) async {
        guard let originalImage else {
            renderedImage = nil
            captionLines = (nil, nil)
            isRendering = false
            return
        }

        let theme = currentTheme
        let spec = makeRenderSpec(theme: theme)
        let lines = makeCaptionLines(theme: theme)
        captionLines = lines

        enqueueRender(request: RenderRequest(
            generation: generation,
            originalImage: originalImage,
            spec: spec,
            lines: lines
        ))
    }

    private func enqueueRender(request: RenderRequest) {
        renderCoordinator.enqueue(request) { [weak self] generation, image in
            Task { @MainActor in
                guard let self else { return }
                guard self.renderGeneration == generation else { return }
                self.lastRenderedGeneration = generation
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.renderedImage = image
                }
                if self.lastRenderedGeneration == self.renderGeneration {
                    self.isRendering = false
                }
            }
        }
    }
    
    func saveRenderedToPhotos() async {
        guard let exported = exportData() else { return }

        isProcessing = true
        defer { isProcessing = false }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            let newStatus = await requestPhotoAuthorization()
            if newStatus != .authorized && newStatus != .limited {
                showError("사진 권한이 필요합니다. Settings에서 권한을 허용해주세요.")
                return
            }
        } else if status != .authorized && status != .limited {
            showError("사진 권한이 필요합니다. Settings에서 권한을 허용해주세요.")
            return
        }
        
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = exported.utType.identifier
                options.originalFilename = "PhotoRava_EXIF.\(exported.fileExtension)"
                request.addResource(with: .photo, data: exported.data, options: options)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success && error == nil {
                        self.showingAnalysisSuggestion = true
                    } else {
                        self.showError("저장에 실패했습니다.")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func shareRendered() {
        guard let url = exportTempFileURL() else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC)
    }

    func cancelBatchExport() {
        batchExportTask?.cancel()
    }

    func startBatchSaveToPhotos() {
        startBatchExport(mode: .saveToPhotos)
    }

    func startBatchShare() {
        startBatchExport(mode: .share)
    }

    func retryFailedBatch() {
        guard !batchExportState.isRunning else { return }
        guard let snapshot = lastBatchSnapshot, let mode = lastBatchMode else { return }
        let failedIndices = batchExportState.results
            .filter { $0.status == .failed }
            .map { $0.index }
            .sorted()
        guard !failedIndices.isEmpty else { return }
        guard failedIndices.allSatisfy({ $0 >= 0 && $0 < lastBatchSources.count }) else { return }
        let retrySources = failedIndices.map { lastBatchSources[$0] }
        startBatchExport(mode: mode, sourcesOverride: retrySources, snapshotOverride: snapshot)
    }

    private struct BatchSnapshot {
        var theme: ExifStampTheme
        var themeOverride: ExifStampThemeOverride
        var photoOverrides: [String: ExifStampThemeOverride]
        var renderSpec: ExifStampRenderSpec
        var captionVisibility: ExifStampMetadataService.CaptionVisibility
        var dateFormatPreset: ExifStampDateFormatPreset
        var exportSettings: ExifStampExportSettings
        var batchFileNameBase: String
    }

    private func makeBatchSnapshot(batchStartedAt: Date) -> BatchSnapshot {
        let theme = currentTheme
        let o = currentOverride()
        let batchIds = Set(batchSources.map { $0.identifier })
        let relevantOverrides = userSettings.photoOverridesById.filter { batchIds.contains($0.key) }
        
        return BatchSnapshot(
            theme: theme,
            themeOverride: o,
            photoOverrides: relevantOverrides,
            renderSpec: makeRenderSpec(theme: theme, override: o),
            captionVisibility: makeCaptionVisibility(theme: theme, override: o),
            dateFormatPreset: effectiveDateFormatPreset(theme: theme, override: o),
            exportSettings: userSettings.exportSettings,
            batchFileNameBase: makeBatchFileNameBase(batchStartedAt: batchStartedAt)
        )
    }

    private func makeBatchFileNameBase(batchStartedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "PhotoRava_EXIF_\(formatter.string(from: batchStartedAt))"
    }

    private func startBatchExport(
        mode: ExifStampBatchExportState.Mode,
        sourcesOverride: [BatchSource]? = nil,
        snapshotOverride: BatchSnapshot? = nil
    ) {
        guard !batchExportState.isRunning else { return }

        let sources = sourcesOverride ?? batchSources
        guard !sources.isEmpty else {
            showError("일괄 내보내기할 사진을 먼저 선택해주세요.")
            return
        }

        let snapshot = snapshotOverride ?? makeBatchSnapshot(batchStartedAt: Date())

        if mode == .share, sources.count > 30 {
            showError("공유는 최대 30장까지 지원합니다. (현재 \(sources.count)장)")
            return
        }

        lastBatchSources = sources
        lastBatchSnapshot = snapshot
        lastBatchMode = mode

        let results = sources.enumerated().map { idx, src in
            ExifStampBatchExportState.ResultItem(index: idx, identifier: src.identifier, status: .pending, message: nil, outputURL: nil)
        }
        
        let initialState = ExifStampBatchExportState(
            isRunning: true,
            mode: mode,
            total: sources.count,
            completed: 0,
            failed: 0,
            currentIndex: 0,
            currentIdentifier: nil,
            lastSummary: nil,
            lastFailures: [],
            results: results
        )
        
        batchExportState = initialState

        batchExportTask?.cancel()
        batchExportTask = Task { [weak self] in
            guard let self else { return }
            await self.runBatchExport(sources: sources, mode: mode, snapshot: snapshot)
        }
    }

    private func runBatchExport(
        sources: [BatchSource],
        mode: ExifStampBatchExportState.Mode,
        snapshot: BatchSnapshot
    ) async {
        if mode == .saveToPhotos {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .notDetermined {
                let newStatus = await requestPhotoAuthorization()
                if newStatus != .authorized && newStatus != .limited {
                    showError("사진 권한이 필요합니다. Settings에서 권한을 허용해주세요.")
                    batchExportState.isRunning = false
                    batchExportState.mode = nil
                    return
                }
            } else if status != .authorized && status != .limited {
                showError("사진 권한이 필요합니다. Settings에서 권한을 허용해주세요.")
                batchExportState.isRunning = false
                batchExportState.mode = nil
                return
            }
        }

        let concurrencyLimit = max(1, min(2, snapshot.exportSettings.batchConcurrencyLimit))
        let urlCollector: BatchShareURLCollector? = (mode == .share) ? BatchShareURLCollector() : nil

        if concurrencyLimit == 1 {
            for (idx, source) in sources.enumerated() {
                if Task.isCancelled { break }
                await processBatchItem(
                    index: idx,
                    source: source,
                    mode: mode,
                    snapshot: snapshot,
                    urlCollector: urlCollector
                )
            }
        } else {
            await withTaskGroup(of: Void.self) { group in
                var nextIndex = 0

                func enqueueNext() {
                    guard nextIndex < sources.count else { return }
                    let idx = nextIndex
                    let source = sources[idx]
                    nextIndex += 1
                    group.addTask { [weak self] in
                        guard let self else { return }
                        if Task.isCancelled { return }
                        await self.processBatchItem(
                            index: idx,
                            source: source,
                            mode: mode,
                            snapshot: snapshot,
                            urlCollector: urlCollector
                        )
                    }
                }

                for _ in 0..<min(concurrencyLimit, sources.count) {
                    enqueueNext()
                }

                while await group.next() != nil {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }
                    enqueueNext()
                }
            }
        }

        let doneCount = batchExportState.completed + batchExportState.failed
        
        await MainActor.run {
            if Task.isCancelled {
                batchExportState.lastSummary = "취소됨: \(doneCount)/\(batchExportState.total) 처리 (실패 \(batchExportState.failed)건)"
            } else {
                batchExportState.lastSummary = "완료: 성공 \(batchExportState.completed)건 / 실패 \(batchExportState.failed)건"
                if batchExportState.completed > 0 {
                    showingAnalysisSuggestion = true
                }
            }

            batchExportState.isRunning = false
            batchExportState.mode = nil
            batchExportState.currentIndex = 0
            batchExportState.currentIdentifier = nil
        }

        if mode == .share, !Task.isCancelled {
            let urls = await urlCollector?.ordered() ?? []
            guard !urls.isEmpty else { return }
            let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            present(activityVC)
        }
    }

    private func processBatchItem(
        index: Int,
        source: BatchSource,
        mode: ExifStampBatchExportState.Mode,
        snapshot: BatchSnapshot,
        urlCollector: BatchShareURLCollector?
    ) async {
        let identifier = source.identifier
        await MainActor.run {
            var newState = self.batchExportState
            newState.currentIndex = index + 1
            newState.currentIdentifier = identifier
            self.batchExportState = newState
        }

        let originalData: Data?
        let asset: PHAsset?
        switch source {
        case .asset(let a):
            asset = a
            originalData = await metadataService.fetchOriginalImageData(for: a)
        case .item(let item, _):
            asset = nil
            originalData = try? await item.loadTransferable(type: Data.self)
        }

        let baseImage: UIImage?
        if let originalData, let image = UIImage(data: originalData) {
            baseImage = image
        } else if let asset {
            baseImage = await fetchThumbnailImage(for: asset, targetSize: CGSize(width: 2600, height: 2600))
        } else {
            baseImage = nil
        }

        guard let baseImage else {
            await MainActor.run { self.recordBatchFailure(index: index, identifier: identifier, message: "이미지 로드 실패") }
            return
        }

        guard let exported = await renderAndExportOne(
            baseImage: baseImage,
            originalData: originalData,
            asset: asset,
            snapshot: snapshot,
            identifier: identifier
        ) else {
            await MainActor.run { self.recordBatchFailure(index: index, identifier: identifier, message: "렌더/인코딩 실패") }
            return
        }

        if Task.isCancelled { return }

        switch mode {
        case .saveToPhotos:
            let ok = await saveExportedToPhotos(exported, index: index + 1, baseName: snapshot.batchFileNameBase)
            await MainActor.run {
                if ok {
                    self.recordBatchSuccess(index: index, outputURL: nil)
                } else {
                    self.recordBatchFailure(index: index, identifier: identifier, message: "저장 실패")
                }
            }
        case .share:
            if let url = writeExportedToTemp(exported, index: index + 1, baseName: snapshot.batchFileNameBase), let urlCollector {
                await urlCollector.set(url, index: index)
                await MainActor.run { self.recordBatchSuccess(index: index, outputURL: url) }
            } else {
                await MainActor.run { self.recordBatchFailure(index: index, identifier: identifier, message: "임시 파일 생성 실패") }
            }
        }
    }

    private func rebuildBatchSelection() {
        let ids = batchSelectedItems.compactMap { $0.itemIdentifier }
        var assetById: [String: PHAsset] = [:]
        if !ids.isEmpty {
            let results = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            results.enumerateObjects { asset, _, _ in
                assetById[asset.localIdentifier] = asset
            }
        }

        var sources: [BatchSource] = []
        sources.reserveCapacity(batchSelectedItems.count)
        for (idx, item) in batchSelectedItems.enumerated() {
            if let id = item.itemIdentifier, let asset = assetById[id] {
                sources.append(.asset(asset))
            } else if let id = item.itemIdentifier {
                sources.append(.item(item: item, identifier: id))
            } else {
                sources.append(.item(item: item, identifier: "item-\(idx)-\(UUID().uuidString)"))
            }
        }
        batchSources = sources

        // 선택 해제된 항목의 썸네일 캐시 정리
        let activeIds = Set(sources.map { $0.identifier })
        thumbnailCache = thumbnailCache.filter { activeIds.contains($0.key) }
    }

    private func recordBatchFailure(index: Int, identifier: String, message: String) {
        Task { @MainActor in
            var newState = self.batchExportState
            newState.failed += 1
            if index >= 0, index < newState.results.count {
                newState.results[index].status = .failed
                newState.results[index].message = message
                newState.results[index].outputURL = nil
            }
            if newState.lastFailures.count < 10 {
                newState.lastFailures.append("\(identifier): \(message)")
            }
            self.batchExportState = newState
        }
    }

    private func recordBatchSuccess(index: Int, outputURL: URL?) {
        Task { @MainActor in
            var newState = self.batchExportState
            newState.completed += 1
            if index >= 0, index < newState.results.count {
                newState.results[index].status = .success
                newState.results[index].message = nil
                newState.results[index].outputURL = outputURL
            }
            self.batchExportState = newState
        }
    }

    private func renderAndExportOne(
        baseImage: UIImage,
        originalData: Data?,
        asset: PHAsset?,
        snapshot: BatchSnapshot,
        identifier: String
    ) async -> ExportedData? {
        await withCheckedContinuation { continuation in
            batchExportQueue.async {
                let exported: ExportedData? = autoreleasepool {
                    let metadata: ExifStampMetadata = {
                        if let originalData {
                            return ExifStampMetadataService.shared.extract(from: originalData, fallbackAsset: asset)
                        }
                        return ExifStampMetadata(capturedAt: asset?.creationDate)
                    }()

                    let lines = ExifStampMetadataService.formatCaptionLines(
                        metadata: metadata,
                        layout: snapshot.theme.layout,
                        visibility: snapshot.captionVisibility,
                        dateFormatPreset: snapshot.dateFormatPreset,
                        locale: .current
                    )

                    var photoSpec = snapshot.renderSpec
                    if let photoOverride = snapshot.photoOverrides[identifier], let crop = photoOverride.cropRect {
                        photoSpec.cropRect = crop
                    }

                    let rendered = StampedImageRenderer.shared.render(
                        originalImage: baseImage,
                        line1: lines.line1,
                        line2: lines.line2,
                        spec: photoSpec
                    )

                    return Self.exportData(
                        image: rendered,
                        originalImageData: originalData,
                        exportSettings: snapshot.exportSettings
                    )
                }
                continuation.resume(returning: exported)
            }
        }
    }

    private func writeExportedToTemp(_ exported: ExportedData, index: Int, baseName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_\(String(format: "%03d", index)).\(exported.fileExtension)")
        do {
            try exported.data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private func saveExportedToPhotos(_ exported: ExportedData, index: Int, baseName: String) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = exported.utType.identifier
                options.originalFilename = "\(baseName)_\(String(format: "%03d", index)).\(exported.fileExtension)"
                request.addResource(with: .photo, data: exported.data, options: options)
            } completionHandler: { success, error in
                continuation.resume(returning: success && error == nil)
            }
        }
    }
    
    private func fetchThumbnailImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    func showImportExportError(_ message: String) {
        showError(message)
    }
    
    private func requestPhotoAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
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

    func preparePhotosForRouteAnalysis() async {
        isProcessing = true
        defer { isProcessing = false }

        var loadedPhotos: [LoadedPhoto] = []
        
        if batchSources.isEmpty {
            // 단일 사진만 있는 경우
            if let image = originalImage, let data = originalImageData {
                let photo = LoadedPhoto(
                    image: image,
                    asset: nil, // PHAsset은 identifier가 없으면 로드하기 까다로우므로 데이터 우선 사용
                    itemIdentifier: UUID().uuidString,
                    originalData: data
                )
                loadedPhotos.append(photo)
            }
        } else {
            // 일괄 선택된 사진들 처리
            for source in batchSources {
                let asset: PHAsset?
                let originalData: Data?
                
                switch source {
                case .asset(let a):
                    asset = a
                    originalData = await metadataService.fetchOriginalImageData(for: a)
                case .item(let item, _):
                    asset = nil
                    originalData = try? await item.loadTransferable(type: Data.self)
                }
                
                let image: UIImage?
                if let originalData, let decoded = UIImage(data: originalData) {
                    image = decoded
                } else if let asset {
                    image = await fetchThumbnailImage(for: asset, targetSize: CGSize(width: 300, height: 300))
                } else {
                    image = nil
                }
                
                if let image {
                    let photo = LoadedPhoto(
                        image: image,
                        asset: asset,
                        itemIdentifier: source.identifier,
                        originalData: originalData
                    )
                    loadedPhotos.append(photo)
                }
            }
        }
        
        if !loadedPhotos.isEmpty {
            AppState.shared.transferToAnalysis(photos: loadedPhotos)
        }
    }

    private func persistSettings() {
        ExifStampUserSettingsPersistence.save(userSettings)
    }

    private func updateOverride(_ mutate: (inout ExifStampThemeOverride) -> Void) {
        let themeId = currentTheme.id
        let themeOverride = userSettings.themeOverridesById[themeId] ?? ExifStampThemeOverride()
        
        var nextOverride = themeOverride
        mutate(&nextOverride)
        
        // If cropRect changed and there's an active photo, save it specifically for this photo
        if nextOverride.cropRect != themeOverride.cropRect, let photoId = activePhotoIdentifier {
            var photoOverride = userSettings.photoOverridesById[photoId] ?? ExifStampThemeOverride()
            photoOverride.cropRect = nextOverride.cropRect
            userSettings.photoOverridesById[photoId] = photoOverride
            
            // Revert the cropRect change for the theme-level override
            nextOverride.cropRect = themeOverride.cropRect
        }
        
        userSettings.themeOverridesById[themeId] = nextOverride
        persistSettings()
        scheduleRender()
    }

    private func currentOverride() -> ExifStampThemeOverride {
        let themeOverride = userSettings.themeOverridesById[currentTheme.id] ?? ExifStampThemeOverride()
        
        // Merge photo-specific overrides if they exist
        guard let photoId = activePhotoIdentifier,
              let photoOverride = userSettings.photoOverridesById[photoId] else {
            return themeOverride
        }
        
        var merged = themeOverride
        if let crop = photoOverride.cropRect {
            merged.cropRect = crop
        }
        return merged
    }

    private func effectivePaddingPreset() -> ExifStampPaddingPreset {
        currentOverride().paddingPreset ?? currentTheme.defaults.paddingPreset
    }

    private func effectiveBackgroundHex() -> String {
        currentOverride().backgroundColorHex ?? currentTheme.defaults.backgroundColorHex
    }

    private func effectiveTextHex() -> String {
        currentOverride().textColorHex ?? currentTheme.defaults.textColorHex
    }

    private func effectiveTextAlignment() -> ExifStampTextAlignment {
        currentOverride().textAlignment ?? currentTheme.defaults.textAlignment
    }

    private func effectiveTextScale() -> Double {
        currentOverride().textScale ?? currentTheme.defaults.textScale
    }

    private func paddingEdgeBinding(
        get: @escaping (ExifStampThemeOverride) -> Double?,
        set: @escaping (inout ExifStampThemeOverride, Double?) -> Void
    ) -> Binding<Double> {
        Binding(
            get: { [weak self] in
                guard let self else { return 0 }
                let base = self.effectivePaddingPreset().baseFraction
                return get(self.currentOverride()) ?? base
            },
            set: { [weak self] newValue in
                self?.updateOverride { o in set(&o, newValue) }
            }
        )
    }

    private func makeRenderSpec(theme: ExifStampTheme) -> ExifStampRenderSpec {
        makeRenderSpec(theme: theme, override: currentOverride())
    }

    private func makeRenderSpec(theme: ExifStampTheme, override o: ExifStampThemeOverride) -> ExifStampRenderSpec {
        let preset = o.paddingPreset ?? theme.defaults.paddingPreset
        let base = preset.baseFraction
        let padding: ExifStampPaddingFractions = {
            if theme.layout == .noFrame {
                return ExifStampPaddingFractions(top: 0, bottom: 0, left: 0, right: 0)
            }
            return ExifStampPaddingFractions(
                top: CGFloat(o.paddingTopFraction ?? base),
                bottom: CGFloat(o.paddingBottomFraction ?? base),
                left: CGFloat(o.paddingLeftFraction ?? base),
                right: CGFloat(o.paddingRightFraction ?? base)
            )
        }()

        let bgHex = o.backgroundColorHex ?? theme.defaults.backgroundColorHex
        let textHex = o.textColorHex ?? theme.defaults.textColorHex
        let bg = UIColor(exifStampHex: bgHex) ?? .white
        let text = UIColor(exifStampHex: textHex) ?? .black
        let alignment = o.textAlignment ?? theme.defaults.textAlignment
        let scale = o.textScale ?? theme.defaults.textScale

        return ExifStampRenderSpec(
            layout: theme.layout,
            paddingFractions: padding,
            backgroundColor: bg,
            textColor: text,
            textAlignment: alignment,
            textScale: CGFloat(scale),
            cropRect: o.cropRect,
            exportSize: userSettings.exportSettings.exportSize,
            canvasRatio: o.canvasRatio ?? theme.defaults.canvasRatio
        )
    }

    private func makeCaptionLines(theme: ExifStampTheme) -> (line1: String?, line2: String?) {
        makeCaptionLines(theme: theme, override: currentOverride(), metadata: metadata)
    }

    private func visibilityBinding(
        defaultValue: @escaping (ExifStampThemeDefaults) -> Bool,
        get: @escaping (ExifStampThemeOverride) -> Bool?,
        set: @escaping (inout ExifStampThemeOverride, Bool?) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                guard let self else { return true }
                return get(self.currentOverride()) ?? defaultValue(self.currentTheme.defaults)
            },
            set: { [weak self] newValue in
                self?.updateOverride { o in set(&o, newValue) }
            }
        )
    }

    private func makeCaptionVisibility(theme: ExifStampTheme) -> ExifStampMetadataService.CaptionVisibility {
        makeCaptionVisibility(theme: theme, override: currentOverride())
    }

    private func makeCaptionVisibility(theme: ExifStampTheme, override o: ExifStampThemeOverride) -> ExifStampMetadataService.CaptionVisibility {
        return ExifStampMetadataService.CaptionVisibility(
            showsMake: o.showsMake ?? theme.defaults.showsMake,
            showsModel: o.showsModel ?? theme.defaults.showsModel,
            showsLens: o.showsLens ?? theme.defaults.showsLens,
            showsISO: o.showsISO ?? theme.defaults.showsISO,
            showsShutter: o.showsShutter ?? theme.defaults.showsShutter,
            showsFNumber: o.showsFNumber ?? theme.defaults.showsFNumber,
            showsFocalLength: o.showsFocalLength ?? theme.defaults.showsFocalLength,
            showsDate: o.showsDate ?? theme.defaults.showsDate
        )
    }

    private func effectiveDateFormatPreset() -> ExifStampDateFormatPreset {
        effectiveDateFormatPreset(theme: currentTheme, override: currentOverride())
    }

    private func effectiveDateFormatPreset(theme: ExifStampTheme, override o: ExifStampThemeOverride) -> ExifStampDateFormatPreset {
        o.dateFormatPreset ?? theme.defaults.dateFormatPreset
    }

    private func makeCaptionLines(
        theme: ExifStampTheme,
        override o: ExifStampThemeOverride,
        metadata: ExifStampMetadata
    ) -> (line1: String?, line2: String?) {
        ExifStampMetadataService.formatCaptionLines(
            metadata: metadata,
            layout: theme.layout,
            visibility: makeCaptionVisibility(theme: theme, override: o),
            dateFormatPreset: effectiveDateFormatPreset(theme: theme, override: o),
            locale: .current
        )
    }

    private struct ExportedData {
        var data: Data
        var utType: UTType
        var fileExtension: String
    }

    private func exportData() -> ExportedData? {
        guard let image = renderedImage else { return nil }
        return Self.exportData(
            image: image,
            originalImageData: originalImageData,
            exportSettings: userSettings.exportSettings
        )
    }

    private nonisolated static func exportData(
        image: UIImage,
        originalImageData: Data?,
        exportSettings: ExifStampExportSettings
    ) -> ExportedData? {
        let format = exportSettings.format
        let q = max(0.0, min(1.0, exportSettings.jpegQuality))

        let data: Data?
        if exportSettings.keepExif,
           let withExif = exportDataWithExif(image: image, format: format, quality: q, originalImageData: originalImageData) {
            data = withExif
        } else {
            data = exportDataWithoutExif(image: image, format: format, quality: q)
        }

        guard let data else { return nil }
        return ExportedData(data: data, utType: format.utType, fileExtension: format.fileExtension)
    }

    private nonisolated static func exportDataWithoutExif(image: UIImage, format: ExifStampExportFormat, quality: Double) -> Data? {
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: CGFloat(quality))
        case .png:
            return image.pngData()
        case .heic:
            return exportHeicData(image: image, quality: quality)
        }
    }

    private nonisolated static func exportHeicData(image: UIImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.0, min(1.0, quality))
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private nonisolated static func exportDataWithExif(
        image: UIImage,
        format: ExifStampExportFormat,
        quality: Double,
        originalImageData: Data?
    ) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        guard let originalImageData,
              let source = CGImageSourceCreateWithData(originalImageData as CFData, nil) else {
            return exportDataWithoutExif(image: image, format: format, quality: quality)
        }

        let originalProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, format.utType.identifier as CFString, 1, nil) else {
            return nil
        }

        var props = originalProps ?? [:]
        if format.supportsQuality {
            props[kCGImageDestinationLossyCompressionQuality] = max(0.0, min(1.0, quality))
        }

        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func exportTempFileURL() -> URL? {
        guard let exported = exportData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRava_EXIF_\(UUID().uuidString).\(exported.fileExtension)")
        do {
            try exported.data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    func shareSettingsJSON() {
        guard let url = exportSettingsJSONTempFileURL() else {
            showError("설정을 내보낼 수 없습니다.")
            return
        }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC)
    }

    func importSettingsJSON(from url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ExifStampUserSettings.self, from: data)
            userSettings = decoded
            persistSettings()
            scheduleRender()
        } catch {
            showError("설정 가져오기에 실패했습니다.")
        }
    }

    private func exportSettingsJSONTempFileURL() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(userSettings)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("PhotoRava_ExifStampSettings_\(UUID().uuidString).json")
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }
}


enum ExifStampError: LocalizedError {
    case failedToLoadImage
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "사진을 불러오지 못했습니다."
        }
    }
}
