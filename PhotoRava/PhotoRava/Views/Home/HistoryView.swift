//
//  HistoryView.swift
//  PhotoRava
//
//  Created by 정종원 on 1/12/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Route.date, order: .reverse) private var routes: [Route]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Group {
                    if routes.isEmpty {
                        emptyStateView
                    } else {
                       routeListView
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock")
                    .font(.system(size: 50))
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 8) {
                Text("저장된 경로가 없습니다")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Home에서 사진을 선택하여\n첫 경로를 만들어보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var routeListView: some View {
        List {
            ForEach(routes) { route in
                NavigationLink {
                    TimelineDetailView(route: route)
                } label: {
                    RouteCardView(route: route)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routes[index])
        }
        try? modelContext.save()
    }
}

