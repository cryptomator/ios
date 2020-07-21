//
//  GoogleDriveCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import Promises
import XCTest

class GoogleDriveCloudProviderIntegrationTests: IntegrationTestWithAuthentication {
	static var setUpErrorForGoogleDrive: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForGoogleDrive
		}
		set {
			setUpErrorForGoogleDrive = newValue
		}
	}

	static let setUpAuthenticationForGoogleDrive = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)
	static var setUpProviderForGoogleDrive = GoogleDriveCloudProvider(with: setUpAuthenticationForGoogleDrive)

	override class var setUpProvider: CloudProvider {
		return setUpProviderForGoogleDrive
	}

	static let remoteRootURLForIntegrationTestAtGoogleDrive = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	override class var remoteRootURLForIntegrationTest: URL {
		return remoteRootURLForIntegrationTestAtGoogleDrive
	}

	let authentication = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)

	override class func setUp() {
		setUpAuthenticationForGoogleDrive.authenticate()
		super.setUp()
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		authentication.authenticate()
		super.provider = GoogleDriveCloudProvider(with: authentication)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: GoogleDriveCloudProviderIntegrationTests.self)
	}

	override func deauthenticate() -> Promise<Void> {
		return authentication.deauthenticate()
	}
}
