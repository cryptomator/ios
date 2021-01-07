//
//  VaultFormat7GoogleDriveIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 22.12.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import XCTest
@testable import Promises
class VaultFormat7GoogleDriveIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat7GoogleDrive: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat7GoogleDrive
		}
		set {
			setUpErrorForVaultFormat7GoogleDrive = newValue
		}
	}

	static let tokenUid = "IntegrationtTest"
	private static let setUpGoogleDriveCredential = MockGoogleDriveAuthenticator.generateAuthorizedCredential(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken, tokenUid: tokenUid)
	private static let cloudProvider = GoogleDriveCloudProvider(with: setUpGoogleDriveCredential)
	private static let vaultPath = CloudPath("/IntegrationTests-Vault7/")

	static var setUpProviderForVaultFormat7GoogleDrive: VaultFormat7ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat7GoogleDrive
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
	}

	private var credential: GoogleDriveCredential!

	override class func setUp() {
		let setUpPromise = cloudProvider.deleteFolderIfExisting(at: vaultPath).then {
			DecoratorFactory.createNewVaultFormat7(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest")
		}.then { decorator in
			setUpProviderForVaultFormat7GoogleDrive = decorator
		}.catch { error in
			print("VaultFormat7GoogleDriveIntegrationTests setup error: \(error)")
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
		let credential = MockGoogleDriveAuthenticator.generateAuthorizedCredential(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken, tokenUid: UUID().uuidString)
		let cloudProvider = GoogleDriveCloudProvider(with: credential)
		DecoratorFactory.createFromExistingVaultFormat7(delegate: cloudProvider, vaultPath: VaultFormat7GoogleDriveIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
			super.provider = decorator
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	override func tearDown() {
		credential?.deauthenticate()
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat7GoogleDriveIntegrationTests.self)
	}
}

