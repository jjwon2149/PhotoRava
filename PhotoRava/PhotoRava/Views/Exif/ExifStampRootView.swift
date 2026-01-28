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

struct ExifStampRootView: View {
    @StateObject private var viewModel = ExifStampViewModel()
    @State private var selectedTab: ExifStampTab = .layout
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.originalImage != nil {
                    TabView(selection: $selectedTab) {
                        ExifStampLayoutTab(viewModel: viewModel)
                            .tabItem { Label("프레임", systemImage: "rectangle.inset.filled") }
                            .tag(ExifStampTab.layout)

                        ExifStampThemeTab(viewModel: viewModel)
                            .tabItem { Label("테마", systemImage: "paintpalette") }
                            .tag(ExifStampTab.theme)

                        ExifStampExportTab(viewModel: viewModel)
                            .tabItem { Label("내보내기", systemImage: "square.and.arrow.up") }
                            .tag(ExifStampTab.export)
                    }
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("EXIF")
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
            }
            .overlay(alignment: .top) {
                if viewModel.isProcessing {
                    ProgressView("처리 중…")
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
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.below.photo")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("EXIF 문구 새기기")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("사진에 패딩을 추가하고\n카메라/노출 정보 등을 하단에 새깁니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

enum ExifStampTab: Hashable {
    case layout
    case theme
    case export
}

private struct ExifStampPreviewCard: View {
    let image: UIImage?
    let isRendering: Bool

    var body: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 240)
                }
            }

            if isRendering {
                ProgressView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExifStampLayoutTab: View {
    @ObservedObject var viewModel: ExifStampViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExifStampPreviewCard(image: viewModel.renderedImage, isRendering: viewModel.isRendering)

                ExifStampOptionsCard(title: "프레임/레이아웃") {
                    HStack {
                        Text("레이아웃")
                        Spacer()
                        Text(viewModel.currentTheme.layout.label)
                            .foregroundStyle(.secondary)
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
                                paddingSlider(label: "상", binding: viewModel.paddingTopBinding)
                                paddingSlider(label: "하", binding: viewModel.paddingBottomBinding)
                                paddingSlider(label: "좌", binding: viewModel.paddingLeftBinding)
                                paddingSlider(label: "우", binding: viewModel.paddingRightBinding)
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
                                Text("\(Int((viewModel.textScaleBinding.wrappedValue * 100).rounded()))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: viewModel.textScaleBinding, in: 0.8...2.2, step: 0.05)
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
    }

    private func paddingSlider(label: String, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("패딩 \(label)")
                Spacer()
                Text("\(Int((binding.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: 0...0.25, step: 0.005)
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
    @State private var showingSettingsImporter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExifStampPreviewCard(image: viewModel.renderedImage, isRendering: viewModel.isRendering)

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
    }
}

private struct ExifStampExportTab: View {
    @ObservedObject var viewModel: ExifStampViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExifStampPreviewCard(image: viewModel.renderedImage, isRendering: viewModel.isRendering)

                ExifStampOptionsCard(title: "내보내기") {
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
                    .disabled(!viewModel.exportFormatBinding.wrappedValue.supportsQuality)

                    Toggle("EXIF 유지(가능한 경우)", isOn: viewModel.keepExifBinding)
                        .disabled(viewModel.originalImageData == nil)

                    if viewModel.originalImageData == nil {
                        Text("이 사진은 원본 데이터 접근이 불가해 EXIF 유지가 적용되지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
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
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 12)
            }
            .padding(.vertical)
        }
    }
}

@MainActor
final class ExifStampViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var isProcessing = false
    @Published var isRendering = false
    @Published var showingError = false
    @Published var errorMessage = ""

    @Published private(set) var originalImage: UIImage?
    @Published private(set) var originalImageData: Data?
    @Published private(set) var metadata = ExifStampMetadata()
    @Published private(set) var captionLines: (line1: String?, line2: String?) = (nil, nil)
    @Published private(set) var renderedImage: UIImage?
    
    private let metadataService = PhotoMetadataService()
    @Published private var userSettings: ExifStampUserSettings
    private var renderTask: Task<Void, Never>?
    private var renderGeneration: UInt = 0
    
    init() {
        self.userSettings = ExifStampUserSettingsPersistence.load()
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
            get: { [weak self] in self?.effectiveTextScale() ?? 1.25 },
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self, originalImage] in
            let image = StampedImageRenderer.shared.render(
                originalImage: originalImage,
                line1: lines.line1,
                line2: lines.line2,
                spec: spec
            )
            Task { @MainActor in
                guard let self, self.renderGeneration == generation else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.renderedImage = image
                }
                self.isRendering = false
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
                    if !success || error != nil {
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

    private func persistSettings() {
        ExifStampUserSettingsPersistence.save(userSettings)
    }

    private func updateOverride(_ mutate: (inout ExifStampThemeOverride) -> Void) {
        let themeId = currentTheme.id
        var overrideValue = userSettings.themeOverridesById[themeId] ?? ExifStampThemeOverride()
        mutate(&overrideValue)
        userSettings.themeOverridesById[themeId] = overrideValue
        persistSettings()
        scheduleRender()
    }

    private func currentOverride() -> ExifStampThemeOverride {
        userSettings.themeOverridesById[currentTheme.id] ?? ExifStampThemeOverride()
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
        let o = currentOverride()
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
            textScale: CGFloat(scale)
        )
    }

    private func makeCaptionLines(theme: ExifStampTheme) -> (line1: String?, line2: String?) {
        ExifStampMetadataService.formatCaptionLines(
            metadata: metadata,
            layout: theme.layout,
            visibility: makeCaptionVisibility(theme: theme),
            dateFormatPreset: effectiveDateFormatPreset(),
            locale: .current
        )
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
        let o = currentOverride()
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
        let o = currentOverride()
        return o.dateFormatPreset ?? currentTheme.defaults.dateFormatPreset
    }

    private struct ExportedData {
        var data: Data
        var utType: UTType
        var fileExtension: String
    }

    private func exportData() -> ExportedData? {
        guard let image = renderedImage else { return nil }
        let format = userSettings.exportSettings.format
        let q = max(0.0, min(1.0, userSettings.exportSettings.jpegQuality))

        let data: Data?
        if userSettings.exportSettings.keepExif, let withExif = exportDataWithExif(image: image, format: format, quality: q) {
            data = withExif
        } else {
            data = exportDataWithoutExif(image: image, format: format, quality: q)
        }

        guard let data else { return nil }
        return ExportedData(data: data, utType: format.utType, fileExtension: format.fileExtension)
    }

    private func exportDataWithoutExif(image: UIImage, format: ExifStampExportFormat, quality: Double) -> Data? {
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: CGFloat(quality))
        case .png:
            return image.pngData()
        case .heic:
            return exportHeicData(image: image, quality: quality)
        }
    }

    private func exportHeicData(image: UIImage, quality: Double) -> Data? {
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

    private func exportDataWithExif(image: UIImage, format: ExifStampExportFormat, quality: Double) -> Data? {
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
