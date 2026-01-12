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
                    Button("완료") {
                        saveChanges()
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
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        route.photoRecords.remove(atOffsets: offsets)
    }
    
    private func moveRecords(from source: IndexSet, to destination: Int) {
        route.photoRecords.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveChanges() {
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteRoute() {
        modelContext.delete(route)
        try? modelContext.save()
        dismiss()
    }
}

