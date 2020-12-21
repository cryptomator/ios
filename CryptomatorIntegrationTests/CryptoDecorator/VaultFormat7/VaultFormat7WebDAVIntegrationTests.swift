//
//  VaultFormat7WebDAVIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 19.12.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import XCTest
@testable import Promises
class VaultFormat7WebDAVIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForVaultFormat7WebDAV: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForVaultFormat7WebDAV
		}
		set {
			setUpErrorForVaultFormat7WebDAV = newValue
		}
	}

	private static let setUpClientForWebDAV = WebDAVClient(credential: IntegrationTestSecrets.webDAVCredential, sharedContainerIdentifier: CryptomatorConstants.appGroupName, useBackgroundSession: true)
	private static let cloudProvider = WebDAVProvider(with: setUpClientForWebDAV)
	private static let vaultPath = CloudPath("/IntegrationTests-Vault7/")

	static var setUpProviderForVaultFormat7WebDAV: VaultFormat7ProviderDecorator?

	override class var setUpProvider: CloudProvider? {
		return setUpProviderForVaultFormat7WebDAV
	}

	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
	}

	override class func setUp() {
		let setUpPromise = cloudProvider.deleteFolderIfExisting(at: vaultPath).then {
			DecoratorFactory.createNewVaultFormat7(delegate: cloudProvider, vaultPath: vaultPath, password: "IntegrationTest")
		}.then { decorator in
			setUpProviderForVaultFormat7WebDAV = decorator
		}.catch { error in
			print("VaultFormat7WebDAVIntegrationTests setup error: \(error)")
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
		DecoratorFactory.createFromExistingVaultFormat7(delegate: VaultFormat7WebDAVIntegrationTests.cloudProvider, vaultPath: VaultFormat7WebDAVIntegrationTests.vaultPath, password: "IntegrationTest").then { decorator in
			super.provider = decorator
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: VaultFormat7WebDAVIntegrationTests.self)
	}
}
