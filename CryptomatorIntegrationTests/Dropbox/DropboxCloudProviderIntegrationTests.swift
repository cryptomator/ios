//
//  DropboxCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 05.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess

import Promises
import XCTest
@testable import CloudAccessPrivateCore
@testable import ObjectiveDropboxOfficial

class DropboxCloudProviderIntegrationTests: IntegrationTestWithAuthentication {
	static var setUpErrorForDropbox: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForDropbox
		}
		set {
			setUpErrorForDropbox = newValue
		}
	}

	static let setUpDropboxCredential = MockDropboxCredential()
	static let setUpProviderForDropbox = DropboxCloudProvider(with: setUpDropboxCredential)

	override class var setUpProvider: CloudProvider {
		return setUpProviderForDropbox
	}

	let credential = MockDropboxCredential()
	static let rootCloudPathForIntegrationTestAtDropbox = CloudPath("/iOS-IntegrationTest/plain/")
	override class var rootCloudPathForIntegrationTest: CloudPath {
		return rootCloudPathForIntegrationTestAtDropbox
	}

	override class func setUp() {
		super.setUp()
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		credential.setAuthorizedClient()
		super.provider = DropboxCloudProvider(with: credential)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: DropboxCloudProviderIntegrationTests.self)
	}

	override func deauthenticate() -> Promise<Void> {
		credential.deauthenticate()
		return Promise(())
	}
}
