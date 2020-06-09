//
//  DropboxCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 05.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import ObjectiveDropboxOfficial
import Promises
import XCTest
@testable import CloudAccessPrivate

class DropboxCloudProviderIntegrationTests: CryptomatorIntegrationTestInterface {
	static var setUpErrorForDropbox: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForDropbox
		}
		set {
			setUpErrorForDropbox = newValue
		}
	}

	static let setUpAuthenticationForDropbox = MockDropboxCloudAuthentication()
	static let setUpProviderForDropbox = DropboxCloudProvider(with: setUpAuthenticationForDropbox)
	override class var setUpAuthentication: MockCloudAuthentication {
		return setUpAuthenticationForDropbox
	}

	override class var setUpProvider: CloudProvider {
		return setUpProviderForDropbox
	}

	static let remoteRootURLForIntegrationTestAtGoogleDrive = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	override class var remoteRootURLForIntegrationTest: URL {
		return remoteRootURLForIntegrationTestAtGoogleDrive
	}

	override class func setUp() {
		DBClientsManager.setup(withAppKey: CloudAccessSecrets.dropboxAppKey)
		DBGlobalErrorResponseHandler.registerNetworkErrorResponseBlock(DropboxCloudProvider.networkErrorResponse)
		super.setUp()
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		let auth = MockDropboxCloudAuthentication()
		super.authentication = auth
		super.provider = DropboxCloudProvider(with: auth)
		super.remoteRootURLForIntegrationTest = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: DropboxCloudProviderIntegrationTests.self)
	}
}
