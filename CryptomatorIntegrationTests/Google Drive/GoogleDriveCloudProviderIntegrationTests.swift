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
	override class var setUpError: Error? {
		get {
			return setUpErrorForGoogleDrive
		}
		set {
			setUpErrorForGoogleDrive = newValue
		}
	}

	override class func setUp() {
		let auth = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)
		let provider = GoogleDriveCloudProvider(with: auth)
		let remoteURL = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
		setUpForIntegrationTest(at: provider, with: auth, remoteRootURLForIntegrationTest: remoteURL)
	}

	override func setUpWithError() throws {
		if let error = GoogleDriveCloudProviderIntegrationTests.setUpError {
			throw error
		}
		let auth = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)
		super.authentication = auth
		super.provider = GoogleDriveCloudProvider(with: auth)
		super.remoteRootURLForIntegrationTest = URL(fileURLWithPath: "/iOS-IntegrationTest/plain/", isDirectory: true)
	}
	

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: GoogleDriveCloudProviderIntegrationTests.self)
	}
}
