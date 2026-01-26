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

struct ExifStampRootView: View {
    @StateObject private var viewModel = ExifStampViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if let rendered = viewModel.renderedImage {
                    editorView(rendered: rendered)
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
    
    private func editorView(rendered: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                
                optionsCard
                    .padding(.horizontal)
                
                actionButtons
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("옵션")
                .font(.headline)
            
            HStack {
                Text("패딩")
                Spacer()
                Picker("패딩", selection: $viewModel.style.paddingPreset) {
                    ForEach(ExifStampStyle.PaddingPreset.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                Text("배경")
                Spacer()
                Picker("배경", selection: $viewModel.backgroundPreset) {
                    Text("화이트").tag(ExifStampBackgroundPreset.white)
                    Text("블랙").tag(ExifStampBackgroundPreset.black)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            
            HStack {
                Text("정렬")
                Spacer()
                Picker("정렬", selection: $viewModel.style.textAlignment) {
                    ForEach(ExifStampTextAlignment.allCases) { a in
                        Text(a.label).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("문구 크기")
                    Spacer()
                    Text("\(Int((viewModel.style.textScale * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.textScaleBinding, in: 0.8...2.2, step: 0.05)
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
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: viewModel.style) { _, _ in
            viewModel.regenerateRenderedImage()
        }
        .onChange(of: viewModel.backgroundPreset) { _, _ in
            viewModel.applyBackgroundPreset()
            viewModel.regenerateRenderedImage()
        }
    }
    
    private var actionButtons: some View {
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
}

enum ExifStampBackgroundPreset: String, CaseIterable, Identifiable {
    case white
    case black
    
    var id: String { rawValue }
}

@MainActor
final class ExifStampViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var isProcessing = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    @Published var style = ExifStampStyle()
    @Published var backgroundPreset: ExifStampBackgroundPreset = .white
    
    @Published private(set) var originalImage: UIImage?
    @Published private(set) var originalImageData: Data?
    @Published private(set) var metadata = ExifStampMetadata()
    @Published private(set) var captionLines: (line1: String?, line2: String?) = (nil, nil)
    @Published private(set) var renderedImage: UIImage?
    
    private let metadataService = PhotoMetadataService()
    
    var textScaleBinding: Double {
        get { Double(style.textScale) }
        set { style.textScale = CGFloat(newValue) }
    }
    
    func applyBackgroundPreset() {
        switch backgroundPreset {
        case .white:
            style.backgroundColor = .white
            style.textColor = .black
        case .black:
            style.backgroundColor = .black
            style.textColor = .white
        }
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
            
            captionLines = ExifStampMetadataService.formatCaptionLines(metadata: metadata, locale: .current)
            regenerateRenderedImage()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func regenerateRenderedImage() {
        guard let originalImage else {
            renderedImage = nil
            return
        }
        
        let lines = ExifStampMetadataService.formatCaptionLines(metadata: metadata, locale: .current)
        captionLines = lines
        renderedImage = StampedImageRenderer.shared.render(
            originalImage: originalImage,
            line1: lines.line1,
            line2: lines.line2,
            style: style
        )
    }
    
    func saveRenderedToPhotos() async {
        guard let image = renderedImage else { return }
        
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
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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
        guard let image = renderedImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
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
