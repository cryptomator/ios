// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CloudAccessPrivate",
	platforms: [
		.iOS(.v11),
		.macOS(.v10_12)
	],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "CloudAccessPrivate",
			targets: ["CloudAccessPrivate"]
		),
		.library(
			name: "CloudAccessPrivateCore",
			targets: ["CloudAccessPrivateCore"]
		)
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/google/GTMAppAuth.git", .upToNextMinor(from: "1.1.0")),
		.package(url: "https://github.com/openid/AppAuth-iOS.git", .upToNextMinor(from: "1.4.0")),
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .upToNextMinor(from: "0.9.1")),
		.package(url: "https://github.com/phil1995/dropbox-sdk-obj-c.git", .branch("main")),
		.package(url: "https://github.com/google/google-api-objectivec-client-for-rest.git", .upToNextMinor(from: "1.4.3")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.7.0"))

	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "CloudAccessPrivate",
			dependencies: [
				"AppAuth",
				"CloudAccessPrivateCore"
			]
		),
		.target(
			name: "CloudAccessPrivateCore",
			dependencies: [
				"CocoaLumberjackSwift",
				"CryptomatorCloudAccess",
				"GoogleAPIClientForREST_Drive",
				"GTMAppAuth",
				"ObjectiveDropboxOfficial"
			]
		),
		.testTarget(
			name: "CloudAccessPrivateCoreTests",
			dependencies: ["CloudAccessPrivateCore"]
		)
	]
)
