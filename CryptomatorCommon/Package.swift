// swift-tools-version:5.1

import PackageDescription
let package = Package(
	name: "CryptomatorCommon",
	platforms: [
		.iOS(.v11)
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
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .branch("feature/cloud-access-private-merge")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.7.0"))
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
				"CryptomatorCloudAccessCore"
			]
		),
		.testTarget(
			name: "CryptomatorCommonCoreTests",
			dependencies: ["CryptomatorCommonCore"]
		)
	]
)
