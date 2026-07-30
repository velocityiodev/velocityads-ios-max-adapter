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
        .package(
            url: "https://github.com/AppLovin/AppLovin-MAX-SDK-iOS",
            .upToNextMajor(from: "13.0.0")
        ),
        // Production VelocityAdsSDK distribution.
        // For local development, replace with:
        //   .package(path: "../velocityads-ios-sdk-internal")
        .package(
            url: "https://github.com/velocityiodev/velocityads-ios-sdk",
            .upToNextMajor(from: "0.10.0")
        )
    ],
    targets: [
        .target(
            name: "VelocityAdsMaxAdapter",
            dependencies: [
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "VelocityAdsSDK", package: "velocityads-ios-sdk")
            ]
        )
    ]
)
