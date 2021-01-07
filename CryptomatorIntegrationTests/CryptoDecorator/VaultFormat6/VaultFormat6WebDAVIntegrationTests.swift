//
//  VaultFormat6WebDAVIntegrationTests.swift
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
class VaultFormat6WebDAVIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat6WebDAV: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat6WebDAV
		}
		set {
			setUpErrorForVaultFormat6WebDAV = newValue
		}
	}

	private static let setUpClientForWebDAV = WebDAVClient(credential: IntegrationTestSecrets.webDAVCredential, sharedContainerIdentifier: CryptomatorConstants.appGroupName, useBackgroundSession: true)
	private static let cloudProvider = WebDAVProvider(with: setUpClientForWebDAV)
	private static let vaultPath = CloudPath("/IntegrationTests-Vault6/")

	static var setUpProviderForVaultFormat6WebDAV: VaultFormat6ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat6WebDAV
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
	}

	override class func setUp() {
		let setUpPromise = cloudProvider.deleteFolderIfExisting(at: vaultPath).then {
			DecoratorFactory.createNewVaultFormat6(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest")
		}.then { decorator in
			setUpProviderForVaultFormat6WebDAV = decorator
		}.catch { error in
			print("VaultFormat6WebDAVIntegrationTests setup error: \(error)")
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
		DecoratorFactory.createFromExistingVaultFormat6(delegate: VaultFormat6WebDAVIntegrationTests.cloudProvider, vaultPath: VaultFormat6WebDAVIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
			super.provider = decorator
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat6WebDAVIntegrationTests.self)
	}
}
