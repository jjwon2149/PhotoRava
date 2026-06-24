//
//  RouteListAdBannerView.swift
//  PhotoRava
//
//  Created by Codex on 6/24/26.
//

import GoogleMobileAds
import SwiftUI
import UIKit

struct RouteListAdBannerView: View {
    @State private var loadState: AdMobBannerLoadState = .loading

    var body: some View {
        if AdMobConfiguration.isTestApplicationConfigured {
            AdMobBannerContainer(
                adUnitID: AdMobConfiguration.routeListTestBannerAdUnitIdentifier,
                loadState: $loadState
            )
            .frame(maxWidth: .infinity)
            .frame(height: loadState.visibleHeight)
            .opacity(loadState.isVisible ? 1 : 0)
            .clipped()
            .accessibilityHidden(!loadState.isVisible)
            .animation(.easeOut(duration: 0.2), value: loadState.visibleHeight)
        }
    }
}

private enum AdMobBannerLoadState: Equatable {
    case loading
    case loaded(CGFloat)
    case failed

    var visibleHeight: CGFloat {
        switch self {
        case .loading:
            return 1
        case .loaded(let height):
            return max(height, 1)
        case .failed:
            return 0
        }
    }

    var isVisible: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

private struct AdMobBannerContainer: UIViewControllerRepresentable {
    let adUnitID: String
    @Binding var loadState: AdMobBannerLoadState

    func makeUIViewController(context: Context) -> AdMobBannerViewController {
        let controller = AdMobBannerViewController(adUnitID: adUnitID)
        updateStateHandler(on: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: AdMobBannerViewController, context: Context) {
        uiViewController.adUnitID = adUnitID
        updateStateHandler(on: uiViewController)
    }

    private func updateStateHandler(on controller: AdMobBannerViewController) {
        let loadState = $loadState
        controller.onLoadStateChange = { state in
            DispatchQueue.main.async {
                loadState.wrappedValue = state
            }
        }
    }
}

private final class AdMobBannerViewController: UIViewController, BannerViewDelegate {
    var adUnitID: String {
        didSet {
            guard oldValue != adUnitID else { return }

            requestedAdUnitID = nil
            requestBannerIfNeeded()
        }
    }

    var onLoadStateChange: ((AdMobBannerLoadState) -> Void)?

    private let bannerView = BannerView()
    private var requestedAdUnitID: String?
    private var requestedWidth: CGFloat?
    private var requestTimedOut = false
    private var timeoutWorkItem: DispatchWorkItem?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        bannerView.backgroundColor = .clear
        bannerView.delegate = self
        bannerView.rootViewController = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        requestBannerIfNeeded()
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard !requestTimedOut else { return }

        timeoutWorkItem?.cancel()
        onLoadStateChange?(.loaded(bannerView.adSize.size.height))
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        timeoutWorkItem?.cancel()
        onLoadStateChange?(.failed)
    }

    deinit {
        timeoutWorkItem?.cancel()
    }

    private func requestBannerIfNeeded() {
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        guard width > 0 else { return }

        if requestedAdUnitID == adUnitID,
           let requestedWidth,
           abs(requestedWidth - width) < 1 {
            return
        }

        requestedAdUnitID = adUnitID
        requestedWidth = width
        requestTimedOut = false

        let adSize = largeAnchoredAdaptiveBanner(width: width)
        bannerView.adUnitID = adUnitID
        bannerView.adSize = adSize
        bannerView.load(Request())

        onLoadStateChange?(.loading)
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }

            requestTimedOut = true
            onLoadStateChange?(.failed)
        }

        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
    }
}
