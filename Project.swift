import ProjectDescription

let project = Project(
    name: "PhotoRava",
    organizationName: "PhotoRava",
    packages: [
        .remote(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            requirement: .upToNextMajor(from: "13.5.0")
        )
    ],
    targets: [
        .target(
            name: "PhotoRava",
            destinations: .iOS,
            product: .app,
            bundleId: "com.jjwon2149.PhotoRava",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "PhotoRava/PhotoRava/Derived/InfoPlists/PhotoRava-Info.plist"),
            sources: [
                .glob(
                    "PhotoRava/PhotoRava/**/*.swift",
                    excluding: ["PhotoRava/PhotoRava/Derived/Sources/**"]
                )
            ],
            resources: [
                "PhotoRava/PhotoRava/Assets.xcassets"
            ],
            dependencies: [
                .package(product: "GoogleMobileAds")
            ],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CURRENT_PROJECT_VERSION": "1",
                    "DEVELOPMENT_TEAM": "",
                    "GENERATE_INFOPLIST_FILE": "NO",
                    "MARKETING_VERSION": "1.0.0",
                    "PRODUCT_NAME": "PhotoRava",
                    "SWIFT_VERSION": "5.0",
                    "TARGETED_DEVICE_FAMILY": "1",
                    // Official Google demo IDs. Override these build settings privately for release builds.
                    "ADMOB_APPLICATION_IDENTIFIER": "ca-app-pub-3940256099942544~1458002511",
                    "ADMOB_ROUTE_LIST_BANNER_AD_UNIT_IDENTIFIER": "ca-app-pub-3940256099942544/2435281174"
                ]
            )
        )
    ]
)
