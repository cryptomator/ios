//
//  VaultFormat7LocalFileSystemProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 23.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import CloudAccessPrivate
import XCTest
import CloudAccessPrivateCore
@testable import CryptomatorCloudAccess
@testable import CryptomatorCryptoLib
@testable import Promises
class VaultFormat7LocalFileSystemCloudProviderIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat7LocalFileSystem: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat7LocalFileSystem
		}
		set {
			setUpErrorForVaultFormat7LocalFileSystem = newValue
		}
	}

	private static let cloudProvider = LocalFileSystemProvider(rootURL: URL(fileURLWithPath: "/"))
	private static let vaultPath = CloudPath(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).path + "/")

	static var setUpProviderForVaultFormat7LocalFileSystem: VaultFormat7ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat7LocalFileSystem
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtVaultFormat7LocalFileSystem = CloudPath("/")
	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtVaultFormat7LocalFileSystem
	}

	override class func setUp() {
		// TODO: SetUp Vault
		let setUpPromise = DecoratorFactory.createNewVault7(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest").then { decorator in
			setUpProviderForVaultFormat7LocalFileSystem = decorator
		}.catch { error in
			print("VaultFormat7LocalFileSystemCloudProviderIntegrationTests setup error: \(error)")
		}
		guard waitForPromises(timeout: 60.0) else {
			classSetUpError = IntegrationTestError.oneTimeSetUpTimeout
			return
		}
		if let error = setUpPromise.error {
			classSetUpError = error
			return
		}
		super.setUp()
	}

	override func setUpWithError() throws {
		let expectation = XCTestExpectation()
		try super.setUpWithError()
		try FileManager.default.createDirectory(atPath: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.vaultPath.path, withIntermediateDirectories: true, attributes: nil)
		let cloudProvider = LocalFileSystemProvider(rootURL: URL(fileURLWithPath: "/"))
		DecoratorFactory.createFromExistingVault7(delegate: cloudProvider, vaultPath: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
			super.provider = decorator
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat7LocalFileSystemCloudProviderIntegrationTests.self)
	}
}
