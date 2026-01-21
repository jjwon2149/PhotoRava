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
            Group {
                if routes.isEmpty {
                    emptyStateView
                } else {
                    routeListView
                }
            }
            .navigationTitle("History")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("저장된 경로가 없습니다")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Home에서 사진을 선택하여\n첫 경로를 만들어보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(.plain)
    }
    
    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routes[index])
        }
        try? modelContext.save()
    }
}

