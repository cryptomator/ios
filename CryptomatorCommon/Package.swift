// swift-tools-version:5.9

//
//  Package.swift
//  CryptomatorCommon
//
//  Created by Philipp Schmid on 04.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import PackageDescription

let package = Package(
	name: "CryptomatorCommon",
	platforms: [
		.iOS(.v14)
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
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .upToNextMinor(from: "1.9.0")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.8.0")),
		.package(url: "https://github.com/PhilLibs/simple-swift-dependencies", .upToNextMajor(from: "0.1.0")),
		.package(url: "https://github.com/siteline/SwiftUI-Introspect.git", .upToNextMajor(from: "0.3.0")),
		.package(url: "https://github.com/leif-ibsen/SwiftECC", from: "5.0.0")
	],
	targets: [
		.target(
			name: "CryptomatorCommon",
			dependencies: [
				"CryptomatorCommonCore",
				.product(name: "CryptomatorCloudAccess", package: "cloud-access-swift")
			]
		),
		.target(
			name: "CryptomatorCommonCore",
			dependencies: [
				.product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
				.product(name: "CryptomatorCloudAccessCore", package: "cloud-access-swift"),
				.product(name: "Dependencies", package: "simple-swift-dependencies"),
				.product(name: "Introspect", package: "SwiftUI-Introspect"),
				.product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
				.product(name: "SwiftECC", package: "SwiftECC")
			]
		),
		.testTarget(
			name: "CryptomatorCommonCoreTests",
			dependencies: ["CryptomatorCommonCore"]
		)
	]
)
