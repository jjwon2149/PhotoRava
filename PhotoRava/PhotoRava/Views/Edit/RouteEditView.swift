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
    @State private var showingSaveSuccess = false
    @State private var isRecalculating = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("경로 이름", text: $route.name)
                        .font(.headline)
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
            .alert("저장 완료", isPresented: $showingSaveSuccess) {
                Button("확인") {
                    dismiss()
                }
            } message: {
                Text("경로 정보가 성공적으로 업데이트되었습니다.")
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        route.photoRecords.remove(atOffsets: offsets)
    }
    
    private func moveRecords(from source: IndexSet, to destination: Int) {
        route.photoRecords.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveChanges() async {
        isRecalculating = true
        
        // 파생 데이터 재계산 (좌표, 거리, 시간, 도로명 목록)
        await RouteReconstructionService.shared.recalculateRouteData(for: route)
        
        // SwiftData에 저장
        try? modelContext.save()
        
        isRecalculating = false
        showingSaveSuccess = true
    }
    
    private func deleteRoute() {
        modelContext.delete(route)
        try? modelContext.save()
        dismiss()
    }
}


