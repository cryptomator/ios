// swift-tools-version:6.0

//
//  Package.swift
//  CryptomatorCommon
//
//  Created by Philipp Schmid on 04.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import PackageDescription

let swiftSettings: [SwiftSetting] = [
	.enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
	name: "CryptomatorCommon",
	platforms: [
		.iOS(.v17)
	],
	products: [
		.library(
			name: "CryptomatorCommon",
			targets: ["CryptomatorCommon"]
		),
		.library(
			name: "CryptomatorCommonCore",
			targets: ["CryptomatorCommonCore"]
		)
	],
	dependencies: [
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .upToNextMinor(from: "4.0.0")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.10.0")),
		.package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMajor(from: "1.12.0")),
		.package(url: "https://github.com/leif-ibsen/SwiftECC", .upToNextMinor(from: "5.5.0"))
	],
	targets: [
		.target(
			name: "CryptomatorCommon",
			dependencies: [
				"CryptomatorCommonCore",
				.product(name: "CryptomatorCloudAccess", package: "cloud-access-swift")
			],
			swiftSettings: swiftSettings
		),
		.target(
			name: "CryptomatorCommonCore",
			dependencies: [
				.product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
				.product(name: "CryptomatorCloudAccessCore", package: "cloud-access-swift"),
				.product(name: "Dependencies", package: "swift-dependencies"),
				.product(name: "SwiftECC", package: "SwiftECC")
			],
			swiftSettings: swiftSettings
		),
		.testTarget(
			name: "CryptomatorCommonCoreTests",
			dependencies: ["CryptomatorCommonCore"],
			swiftSettings: swiftSettings
		)
	],
	swiftLanguageModes: [.v6]
)
