//
//  WebDAVCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 12.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import Promises
import XCTest

class WebDAVCloudProviderIntegrationTests: IntegrationTestWithAuthentication {
	static var setUpErrorForWebDAV: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForWebDAV
		}
		set {
			setUpErrorForWebDAV = newValue
		}
	}

	static let setUpClientForWebDAV = WebDAVClient(credential: IntegrationTestSecrets.webDAVCredential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
	static let setUpProviderForWebDAV = WebDAVProvider(with: setUpClientForWebDAV)

	override class var setUpProvider: CloudProvider {
		return setUpProviderForWebDAV
	}

	static let rootCloudPathForIntegrationTestAtWebDAV = CloudPath("/iOSIntegrationTests/")

	override class var rootCloudPathForIntegrationTest: CloudPath {
		return rootCloudPathForIntegrationTestAtWebDAV
	}

	override func setUpWithError() throws {
		try super.setUpWithError()
		let client = WebDAVClient(credential: IntegrationTestSecrets.webDAVCredential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		super.provider = WebDAVProvider(with: client)
	}

	override func deauthenticate() -> Promise<Void> {
		let correctCredential = IntegrationTestSecrets.webDAVCredential
		let invalidCredential = WebDAVCredential(baseURL: correctCredential.baseURL, username: correctCredential.username, password: correctCredential.password + "Foo", allowedCertificate: correctCredential.allowedCertificate)
		let client = WebDAVClient(credential: invalidCredential, sharedContainerIdentifier: CryptomatorConstants.appGroupName)
		super.provider = WebDAVProvider(with: client)
		return Promise(())
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: WebDAVCloudProviderIntegrationTests.self)
	}
}
