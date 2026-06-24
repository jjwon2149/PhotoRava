//
//  AdMobService.swift
//  PhotoRava
//
//  Created by Codex on 6/24/26.
//

import Foundation
import GoogleMobileAds

enum AdMobConfiguration {
    static var isConfigured: Bool {
        configuredApplicationIdentifier != nil && routeListBannerAdUnitIdentifier != nil
    }

    static var routeListBannerAdUnitIdentifier: String? {
        cleanedBundleString(for: "PhotoRavaRouteListBannerAdUnitIdentifier")
    }

    private static var configuredApplicationIdentifier: String? {
        cleanedBundleString(for: "GADApplicationIdentifier")
    }

    private static func cleanedBundleString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let cleanedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedValue.isEmpty,
              !cleanedValue.hasPrefix("$(") else {
            return nil
        }

        return cleanedValue
    }
}

final class AdMobService {
    static let shared = AdMobService()

    private var didStart = false

    private init() {}

    func startIfConfigured() {
        guard !didStart, AdMobConfiguration.isConfigured else { return }

        MobileAds.shared.start()
        didStart = true
    }
}
