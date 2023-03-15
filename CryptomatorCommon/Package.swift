// swift-tools-version:5.7

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
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", branch: "feature/hub-poc"),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.8.0"))
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
				.product(name: "CryptomatorCloudAccessCore", package: "cloud-access-swift")
			]
		),
		.testTarget(
			name: "CryptomatorCommonCoreTests",
			dependencies: ["CryptomatorCommonCore"]
		)
	]
)
