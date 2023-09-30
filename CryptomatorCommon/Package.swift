// swift-tools-version:5.1

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
		.iOS(.v13)
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
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .upToNextMinor(from: "1.7.0")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.8.0")),
		.package(url: "https://github.com/PhilLibs/simple-swift-dependencies", .upToNextMajor(from: "0.1.0"))
	],
	targets: [
		.target(
			name: "CryptomatorCommon",
			dependencies: [
				"CryptomatorCommonCore",
				"CryptomatorCloudAccess"
			]
		),
		.target(
			name: "CryptomatorCommonCore",
			dependencies: [
				"CocoaLumberjackSwift",
				"CryptomatorCloudAccessCore",
				.product(name: "Dependencies", package: "simple-swift-dependencies")
			]
		),
		.testTarget(
			name: "CryptomatorCommonCoreTests",
			dependencies: ["CryptomatorCommonCore"]
		)
	]
)
