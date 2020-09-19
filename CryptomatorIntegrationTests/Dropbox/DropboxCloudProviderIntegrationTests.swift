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
@testable import CloudAccessPrivate
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

	static let setUpAuthenticationForDropbox = MockDropboxCloudAuthentication()
	static let setUpProviderForDropbox = DropboxCloudProvider(with: setUpAuthenticationForDropbox)

	override class var setUpProvider: CloudProvider {
		return setUpProviderForDropbox
	}

	let authentication = MockDropboxCloudAuthentication()
	static let rootCloudPathForIntegrationTestAtDropbox = CloudPath("/iOS-IntegrationTest/plain/")
	override class var rootCloudPathForIntegrationTest: CloudPath {
		return rootCloudPathForIntegrationTestAtDropbox
	}

	override class func setUp() {
		setUpAuthenticationForDropbox.authenticate()
		super.setUp()
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		authentication.authenticate()
		super.provider = DropboxCloudProvider(with: authentication)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: DropboxCloudProviderIntegrationTests.self)
	}

	override func deauthenticate() -> Promise<Void> {
		return authentication.deauthenticate()
	}
}
