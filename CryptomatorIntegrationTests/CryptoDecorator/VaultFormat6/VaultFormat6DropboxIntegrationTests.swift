//
//  VaultFormat6DropboxIntegrationTests.swift
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
class VaultFormat6DropboxIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat6Dropbox: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat6Dropbox
		}
		set {
			setUpErrorForVaultFormat6Dropbox = newValue
		}
	}

	private static let setUpDropboxCredential = MockDropboxCredential()
	private static let cloudProvider = DropboxCloudProvider(with: setUpDropboxCredential)
	private static let vaultPath = CloudPath("/IntegrationTests-Vault6/")

	static var setUpProviderForVaultFormat6Dropbox: VaultFormat6ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat6Dropbox
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
	}

	override class func setUp() {
		let setUpPromise = cloudProvider.deleteFolderIfExisting(at: vaultPath).then {
			DecoratorFactory.createNewVaultFormat6(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest")
		}.then { decorator in
			setUpProviderForVaultFormat6Dropbox = decorator
		}.catch { error in
			print("VaultFormat6DropboxIntegrationTests setup error: \(error)")
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
		let credential = MockDropboxCredential()
		let cloudProvider = DropboxCloudProvider(with: credential)
		DecoratorFactory.createFromExistingVaultFormat6(delegate: cloudProvider, vaultPath: VaultFormat6DropboxIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
			super.provider = decorator
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat6DropboxIntegrationTests.self)
	}
}
