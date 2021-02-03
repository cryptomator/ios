// swift-tools-version:5.1

import PackageDescription

let package = Package(
	name: "CloudAccessPrivate",
	platforms: [
		.iOS(.v11),
		.macOS(.v10_12)
	],
	products: [
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
		.package(url: "https://github.com/openid/AppAuth-iOS.git", .upToNextMinor(from: "1.4.0")),
		.package(url: "https://github.com/cryptomator/cloud-access-swift.git", .upToNextMinor(from: "0.11.0")),
		.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.7.0")),
		.package(url: "https://github.com/phil1995/dropbox-sdk-obj-c.git", .branch("main")),
		.package(url: "https://github.com/google/google-api-objectivec-client-for-rest.git", .upToNextMinor(from: "1.4.3")),
		.package(url: "https://github.com/google/GTMAppAuth.git", .upToNextMinor(from: "1.1.0")),
		.package(url: "https://github.com/google/gtm-session-fetcher.git", .upToNextMinor(from: "1.4.0"))
	],
	targets: [
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
				"GTMSessionFetcher",
				"ObjectiveDropboxOfficial"
			]
		),
		.testTarget(
			name: "CloudAccessPrivateCoreTests",
			dependencies: ["CloudAccessPrivateCore"]
		)
	]
)
