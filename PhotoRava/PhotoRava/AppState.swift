import SwiftUI
import Photos

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var pendingPhotosForAnalysis: [LoadedPhoto]?
    
    enum Tab {
        case home
        case exif
        case settings
    }
    
    static let shared = AppState()
    
    private init() {}
    
    func transferToAnalysis(photos: [LoadedPhoto]) {
        self.pendingPhotosForAnalysis = photos
        self.selectedTab = .home
    }
}
