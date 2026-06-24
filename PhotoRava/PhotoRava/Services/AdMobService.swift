//
//  AdMobService.swift
//  PhotoRava
//
//  Created by Codex on 6/24/26.
//

import Foundation
import GoogleMobileAds

enum AdMobConfiguration {
    // Official Google demo IDs only. Production AdMob values are PHO-114-gated.
    static let testApplicationIdentifier = "ca-app-pub-3940256099942544~1458002511"
    static let routeListTestBannerAdUnitIdentifier = "ca-app-pub-3940256099942544/2435281174"

    static var isTestApplicationConfigured: Bool {
        configuredApplicationIdentifier == testApplicationIdentifier
    }

    private static var configuredApplicationIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    }
}

final class AdMobService {
    static let shared = AdMobService()

    private var didStart = false

    private init() {}

    func startIfConfigured() {
        guard !didStart, AdMobConfiguration.isTestApplicationConfigured else { return }

        MobileAds.shared.start()
        didStart = true
    }
}
