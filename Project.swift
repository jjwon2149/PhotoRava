import ProjectDescription

let project = Project(
    name: "PhotoRava",
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
                ),
            ],
            resources: ["PhotoRava/PhotoRava/Assets.xcassets"],
            dependencies: [],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "CURRENT_PROJECT_VERSION": "1",
                    "MARKETING_VERSION": "1.0.0",
                    "SWIFT_VERSION": "5.0",
                ]
            )
        ),
    ]
)
