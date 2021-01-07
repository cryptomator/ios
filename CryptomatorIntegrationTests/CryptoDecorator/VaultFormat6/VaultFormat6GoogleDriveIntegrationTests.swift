//
//  VaultFormat6GoogleDriveIntegrationTests.swift
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
class VaultFormat6GoogleDriveIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat6GoogleDrive: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat6GoogleDrive
		}
		set {
			setUpErrorForVaultFormat6GoogleDrive = newValue
		}
	}

	static let tokenUid = "IntegrationtTest"
	private static let setUpGoogleDriveCredential = MockGoogleDriveAuthenticator.generateAuthorizedCredential(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken, tokenUid: tokenUid)
	private static let cloudProvider = GoogleDriveCloudProvider(with: setUpGoogleDriveCredential)
	private static let vaultPath = CloudPath("/IntegrationTests-Vault6/")

	static var setUpProviderForVaultFormat6GoogleDrive: VaultFormat6ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat6GoogleDrive
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
	}

	private var credential: GoogleDriveCredential!

	override class func setUp() {
		let setUpPromise = cloudProvider.deleteFolderIfExisting(at: vaultPath).then {
			DecoratorFactory.createNewVaultFormat6(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest")
		}.then { decorator in
			setUpProviderForVaultFormat6GoogleDrive = decorator
		}.catch { error in
			print("VaultFormat6GoogleDriveIntegrationTests setup error: \(error)")
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
		DecoratorFactory.createFromExistingVaultFormat6(delegate: cloudProvider, vaultPath: VaultFormat6GoogleDriveIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
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
		return XCTestSuite(forTestCaseClass: VaultFormat6GoogleDriveIntegrationTests.self)
	}
}
