//
//  S3AuthenticationViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 30.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class S3AuthenticationViewModelTests: XCTestCase {
	var existingCredentialViewModel: S3AuthenticationViewModel!
	var viewModel: S3AuthenticationViewModel!
	var credentialManagerMock: S3CredentialManagerTypeMock!
	var credentialVerifierMock: S3CredentialVerifierTypeMock!
	let existingDisplayName = "Foo-1234"

	let defaultDisplayName = "Cryptomator S3"
	let defaultAccessKey = "My Access Key"
	let defaultSecretKey = "My Secret Key"
	let defaultExistingBucket = "cryptomator-test"
	let defaultEndpoint = "https://example.com"
	let defaultRegion = "custom-region"

	override func setUpWithError() throws {
		credentialManagerMock = S3CredentialManagerTypeMock()
		credentialVerifierMock = S3CredentialVerifierTypeMock()
		viewModel = S3AuthenticationViewModel(verifier: credentialVerifierMock, credentialManager: credentialManagerMock)
		existingCredentialViewModel = S3AuthenticationViewModel(displayName: existingDisplayName, credential: .stub, verifier: credentialVerifierMock, credentialManager: credentialManagerMock)
	}

	func testInitialStateDefaultViewModel() throws {
		XCTAssertEqual(.notLoggedIn, viewModel.loginState)
		XCTAssert(viewModel.displayName.isEmpty)
		XCTAssert(viewModel.accessKey.isEmpty)
		XCTAssert(viewModel.secretKey.isEmpty)
		XCTAssert(viewModel.existingBucket.isEmpty)
		XCTAssertEqual("https://", viewModel.endpoint)
		XCTAssert(viewModel.region.isEmpty)
	}

	func testInitialStateExistingCredentialViewModel() throws {
		XCTAssertEqual(.notLoggedIn, existingCredentialViewModel.loginState)
		let existingCredential = S3Credential.stub
		XCTAssertEqual(existingDisplayName, existingCredentialViewModel.displayName)
		XCTAssertEqual(existingCredential.accessKey, existingCredentialViewModel.accessKey)
		XCTAssertEqual(existingCredential.secretKey, existingCredentialViewModel.secretKey)
		XCTAssertEqual(existingCredential.bucket, existingCredentialViewModel.existingBucket)
		XCTAssertEqual(existingCredential.url.absoluteString, existingCredentialViewModel.endpoint)
		XCTAssertEqual(existingCredential.region, existingCredentialViewModel.region)
	}

	func testSaveIsDisabled() throws {
		let recorder = viewModel.saveDisabled.recordNext(7)
		viewModel.displayName = "Cryptomator S3"
		viewModel.accessKey = "My Access Key"
		viewModel.secretKey = "My Secret Key"
		viewModel.existingBucket = "cryptomator-test"
		viewModel.endpoint = "https://example.com"
		viewModel.region = "custom-region"
		XCTAssertEqual([true, true, true, true, true, true, false], recorder.getElements())
	}

	func testSaveS3Credential() throws {
		let recorder = viewModel.$loginState.recordNext(3)

		prepareViewModelWithDefaultValues()
		credentialVerifierMock.verifyCredentialReturnValue = Promise(())

		viewModel.saveS3Credential()

		wait(for: recorder, timeout: 1.0)
		let stateChanges = recorder.getElements()
		XCTAssertEqual(3, stateChanges.count)
		XCTAssertEqual(0, stateChanges.firstIndex(of: .notLoggedIn))
		XCTAssertEqual(1, stateChanges.firstIndex(of: .verifyingCredentials))
		let finalState = stateChanges[2]
		XCTAssertEqual(viewModel.loginState, finalState)
		guard case let S3LoginState.loggedIn(credential) = finalState else {
			XCTFail("Unexpected final state: \(finalState)")
			return
		}
		XCTAssertEqual(defaultAccessKey, credential.accessKey)
		XCTAssertEqual(defaultSecretKey, credential.secretKey)
		XCTAssertEqual(defaultExistingBucket, credential.bucket)
		XCTAssertEqual(defaultEndpoint, credential.url.absoluteString)
		XCTAssertEqual(defaultRegion, credential.region)

		XCTAssertEqual(1, credentialManagerMock.saveCredentialDisplayNameCallsCount)
		let receivedArguments = try XCTUnwrap(credentialManagerMock.saveCredentialDisplayNameReceivedArguments)
		XCTAssertEqual(credential, receivedArguments.credential)
	}

	func testSaveS3CredentialFailIfVerificationFails() {
		let recorder = viewModel.$loginState.recordNext(3)

		prepareViewModelWithDefaultValues()
		credentialVerifierMock.verifyCredentialReturnValue = Promise(CloudProviderError.unauthorized)

		viewModel.saveS3Credential()

		wait(for: recorder, timeout: 1.0)
		let stateChanges = recorder.getElements()
		let expectedStateChanges: [S3LoginState] = [.notLoggedIn, .verifyingCredentials, .error(S3AuthenticationViewModelError.invalidCredentials)]
		XCTAssertEqual(expectedStateChanges, stateChanges)
	}

	func testSaveS3CredentialFailIfEndpointIsNonValidURL() {
		let recorder = viewModel.$loginState.recordNext(2)

		prepareViewModelWithDefaultValues()
		viewModel.endpoint = "https://example invalid endpoint"
		credentialVerifierMock.verifyCredentialReturnValue = Promise(())

		viewModel.saveS3Credential()

		wait(for: recorder, timeout: 1.0)
		let stateChanges = recorder.getElements()
		let expectedStateChanges: [S3LoginState] = [.notLoggedIn, .error(S3AuthenticationViewModelError.invalidEndpoint)]
		XCTAssertEqual(expectedStateChanges, stateChanges)
	}

	func testSaveS3CredentialForExistingCredential() {
		let recorder = existingCredentialViewModel.$loginState.recordNext(3)
		credentialVerifierMock.verifyCredentialReturnValue = Promise(())
		existingCredentialViewModel.saveS3Credential()

		wait(for: recorder, timeout: 1.0)
		let stateChanges = recorder.getElements()
		let expectedStateChanges: [S3LoginState] = [.notLoggedIn, .verifyingCredentials, .loggedIn(.stub)]
		XCTAssertEqual(expectedStateChanges, stateChanges)
	}

	private func prepareViewModelWithDefaultValues() {
		viewModel.displayName = defaultDisplayName
		viewModel.accessKey = defaultAccessKey
		viewModel.secretKey = defaultSecretKey
		viewModel.existingBucket = defaultExistingBucket
		viewModel.endpoint = defaultEndpoint
		viewModel.region = defaultRegion
	}
}

private extension S3Credential {
	static let stub = S3Credential(accessKey: "access-key-123", secretKey: "secret-key-345", url: URL(string: "https://example.com")!, bucket: "exampleBucket", region: "customRegion", identifier: "Foo-12345")
}

extension S3LoginState: Equatable {
	public static func == (lhs: S3LoginState, rhs: S3LoginState) -> Bool {
		switch (lhs, rhs) {
		case (.notLoggedIn, .notLoggedIn):
			return true
		case (.verifyingCredentials, .verifyingCredentials):
			return true
		case let (.loggedIn(lhsCredential), .loggedIn(rhsCredential)):
			return lhsCredential == rhsCredential
		case let (.error(lhsError), .error(rhsError)):
			return lhsError as NSError == rhsError as NSError
		default:
			return false
		}
	}
}
