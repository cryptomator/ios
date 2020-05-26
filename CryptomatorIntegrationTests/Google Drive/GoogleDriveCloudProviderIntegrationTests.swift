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

class GoogleDriveCloudProviderIntegrationTests: CryptomatorIntegrationTestInterface {
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
	static let setUpProviderForGoogleDrive = GoogleDriveCloudProvider(with: setUpAuthenticationForGoogleDrive)
	override class var setUpAuthentication: MockCloudAuthentication {
		return setUpAuthenticationForGoogleDrive
	}

	override class var setUpProvider: CloudProvider {
		return setUpProviderForGoogleDrive
	}

	static let remoteRootURLForIntegrationTestAtGoogleDrive = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	override class var remoteRootURLForIntegrationTest: URL {
		return remoteRootURLForIntegrationTestAtGoogleDrive
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		let auth = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)
		super.authentication = auth
		super.provider = GoogleDriveCloudProvider(with: auth)
		super.remoteRootURLForIntegrationTest = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: GoogleDriveCloudProviderIntegrationTests.self)
	}
}
