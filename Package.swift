// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VelocityAdsMaxAdapter",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "VelocityAdsMaxAdapter",
            targets: ["VelocityAdsMaxAdapter"]
        )
    ],
    dependencies: [
        // AppLovin's SPM distribution lives in a dedicated repo with semver tags
        // (the main AppLovin-MAX-SDK-iOS repo tags are not SPM-resolvable).
        .package(
            url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package",
            .upToNextMajor(from: "13.0.0")
        ),
        // Production VelocityAdsSDK distribution.
        // For local development, replace with:
        //   .package(path: "../velocityads-ios-sdk-internal")
        .package(
            url: "https://github.com/velocityiodev/velocityads-ios-sdk",
            .upToNextMinor(from: "0.10.0")
        )
    ],
    targets: [
        .target(
            name: "VelocityAdsMaxAdapter",
            dependencies: [
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
                .product(name: "VelocityAdsSDK", package: "velocityads-ios-sdk")
            ]
        ),
        .testTarget(
            name: "VelocityAdsMaxAdapterTests",
            dependencies: [
                "VelocityAdsMaxAdapter",
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
                .product(name: "VelocityAdsSDK", package: "velocityads-ios-sdk")
            ]
        )
    ]
)
