//
//  PhotoSelectionView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import PhotosUI

struct PhotoSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PhotoPickerViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Photo Grid
                if viewModel.loadedPhotos.isEmpty {
                    emptyPhotoView
                } else {
                    photoGridView
                }
                
                Spacer()
                
                // Bottom Button
                analyzeButton
            }
            .navigationTitle("\(viewModel.selectedCount)장 선택됨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("전체") {
                        viewModel.selectAll()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingPicker) {
                PhotosPicker(
                    selection: $viewModel.selectedItems,
                    maxSelectionCount: 50,
                    matching: .images
                ) {
                    Text("사진 선택")
                }
            }
            .fullScreenCover(isPresented: $viewModel.showingAnalysis) {
                if let photos = viewModel.selectedPhotosForAnalysis {
                    AnalysisProgressView(photos: photos)
                }
            }
            .onAppear {
                viewModel.showingPicker = true
            }
            .onChange(of: viewModel.selectedItems) { _, newItems in
                Task {
                    await viewModel.loadPhotos()
                }
            }
        }
    }
    
    private var emptyPhotoView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("사진을 선택해주세요")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                viewModel.showingPicker = true
            } label: {
                Text("사진 앨범 열기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ], spacing: 2) {
                ForEach(viewModel.loadedPhotos) { photo in
                    PhotoGridCell(
                        photo: photo,
                        isSelected: viewModel.isSelected(photo)
                    ) {
                        viewModel.toggleSelection(photo)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    private var analyzeButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                viewModel.startAnalysis()
            } label: {
                Text("경로 분석하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.canAnalyze ? Color.primaryBlue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canAnalyze)
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}

struct PhotoGridCell: View {
    let photo: LoadedPhoto
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo.image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(isSelected ? Color.primaryBlue : Color.clear, lineWidth: 3)
                    )
                
                // Checkmark
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryBlue : Color.black.opacity(0.3))
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
class PhotoPickerViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var loadedPhotos: [LoadedPhoto] = []
    @Published var showingPicker = false
    @Published var showingAnalysis = false
    
    private var selectedPhotoIDs: Set<UUID> = []
    
    var selectedCount: Int {
        selectedPhotoIDs.count
    }
    
    var canAnalyze: Bool {
        selectedCount > 0
    }
    
    var selectedPhotosForAnalysis: [LoadedPhoto]? {
        guard !selectedPhotoIDs.isEmpty else { return nil }
        return loadedPhotos.filter { selectedPhotoIDs.contains($0.id) }
    }
    
    func loadPhotos() async {
        var newPhotos: [LoadedPhoto] = []
        
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let photo = LoadedPhoto(image: image, asset: nil)
                newPhotos.append(photo)
                selectedPhotoIDs.insert(photo.id)
            }
        }
        
        loadedPhotos = newPhotos
    }
    
    func isSelected(_ photo: LoadedPhoto) -> Bool {
        selectedPhotoIDs.contains(photo.id)
    }
    
    func toggleSelection(_ photo: LoadedPhoto) {
        if selectedPhotoIDs.contains(photo.id) {
            selectedPhotoIDs.remove(photo.id)
        } else {
            selectedPhotoIDs.insert(photo.id)
        }
    }
    
    func selectAll() {
        selectedPhotoIDs = Set(loadedPhotos.map { $0.id })
    }
    
    func startAnalysis() {
        showingAnalysis = true
    }
}

struct LoadedPhoto: Identifiable {
    let id = UUID()
    var image: UIImage
    var asset: PHAsset?
}

