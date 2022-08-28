//
//  WebDAVAuthenticationViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 28.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore

class WebDAVAuthenticationViewModelTests: XCTestCase {
	var viewModel: WebDAVAuthenticationViewModel!
	var credentialManagerMock: WebDAVCredentialManagerMock!
	var validationHelperMock: TLSCertificateValidationHelpingMock!
	var cloudProviderUpdatingMock: CloudProviderUpdatingMock!
	let untrustedCertificate = TLSCertificate(data: WebDAVCredential.mockCertificate, isTrusted: false, fingerprint: UUID().uuidString)
	let trustedCertificate = TLSCertificate(data: Data(), isTrusted: true, fingerprint: UUID().uuidString)
	var verifyClientCallsCount = 0

	override func setUpWithError() throws {
		verifyClientCallsCount = 0
		credentialManagerMock = WebDAVCredentialManagerMock()
		validationHelperMock = TLSCertificateValidationHelpingMock()
		cloudProviderUpdatingMock = CloudProviderUpdatingMock()
		viewModel = WebDAVAuthenticationViewModel(credential: .mock, credentialManager: credentialManagerMock, validationHelper: validationHelperMock, cloudProviderUpdating: cloudProviderUpdatingMock)
	}

	// MARK: - Initial state

	func testInitialState() {
		let viewModel = WebDAVAuthenticationViewModel(credentialManager: credentialManagerMock, validationHelper: validationHelperMock)
		let stateRecorder = viewModel.$state.recordNext(1)
		let saveButtonIsEnabledRecorder = viewModel.saveButtonIsEnabled.recordNext(1)
		wait(for: stateRecorder)
		wait(for: saveButtonIsEnabledRecorder)
		XCTAssertEqual([.initial], stateRecorder.getElements())
		XCTAssertEqual([false], saveButtonIsEnabledRecorder.getElements())
		XCTAssert(viewModel.username.isEmpty)
		XCTAssert(viewModel.password.isEmpty)
		XCTAssertEqual("https://", viewModel.url)
		XCTAssertFalse(viewModel.showAllowInsecureConnectionAlert)
		XCTAssertFalse(viewModel.showUntrustedCertificateError)
	}

	func testInitialStateWithCredential() {
		let stateRecorder = viewModel.$state.recordNext(1)
		let saveButtonIsEnabledRecorder = viewModel.saveButtonIsEnabled.recordNext(1)
		wait(for: stateRecorder)
		wait(for: saveButtonIsEnabledRecorder)
		XCTAssertEqual([.initial], stateRecorder.getElements())
		XCTAssertEqual([true], saveButtonIsEnabledRecorder.getElements())
		XCTAssertEqual("user", viewModel.username)
		XCTAssertEqual("pass", viewModel.password)
		XCTAssertEqual("https://example.com", viewModel.url)
		XCTAssertFalse(viewModel.showAllowInsecureConnectionAlert)
		XCTAssertFalse(viewModel.showUntrustedCertificateError)
	}

	// MARK: - Save account

	func testSaveAccount() throws {
		let viewModel = WebDAVAuthenticationViewModel(credentialManager: credentialManagerMock, validationHelper: validationHelperMock, cloudProviderUpdating: cloudProviderUpdatingMock)
		validationHelperMock.validateUrlReturnValue = Promise(trustedCertificate)
		var verifyClientCallsCount = 0
		viewModel.verifyClient = { _ in
			verifyClientCallsCount += 1
			return Promise(())
		}
		let stateRecorder = viewModel.$state.recordNext(3)
		let saveButtonIsEnabledRecorder = viewModel.saveButtonIsEnabled.recordNext(4)
		viewModel.username = "user"
		viewModel.password = "pass"
		viewModel.url = "https://example.com"
		viewModel.saveAccount()

		wait(for: stateRecorder)
		wait(for: saveButtonIsEnabledRecorder)
		XCTAssertEqual([.initial, .authenticating, .authenticated(.mock)], stateRecorder.getElements())
		XCTAssertEqual([false, false, true, true], saveButtonIsEnabledRecorder.getElements())

		XCTAssertEqual(1, verifyClientCallsCount)
		XCTAssertEqual(1, validationHelperMock.validateUrlCallsCount)
		XCTAssertEqual(1, credentialManagerMock.saveCredentialToKeychainCallsCount)
		let savedCredential = try XCTUnwrap(credentialManagerMock.saveCredentialToKeychainReceivedCredential)
		XCTAssert(savedCredential.isEqual(.mock))
		XCTAssertEqual([savedCredential.identifier], cloudProviderUpdatingMock.providerShouldUpdateWithReceivedInvocations)
	}

	func testUpdateAccount() throws {
		let expectedUpdatedCredential = WebDAVCredential(baseURL: URL(string: "https://example.com")!, username: "user", password: "updatedPassword", allowedCertificate: nil)
		validationHelperMock.validateUrlReturnValue = Promise(trustedCertificate)
		var verifyClientCallsCount = 0
		viewModel.verifyClient = { _ in
			verifyClientCallsCount += 1
			return Promise(())
		}
		let stateRecorder = viewModel.$state.recordNext(3)
		viewModel.username = "user"
		viewModel.password = "updatedPassword"
		viewModel.url = "https://example.com"
		viewModel.saveAccount()

		wait(for: stateRecorder)
		XCTAssertEqual([.initial, .authenticating, .authenticated(expectedUpdatedCredential)], stateRecorder.getElements())

		XCTAssertEqual(1, verifyClientCallsCount)
		XCTAssertEqual(1, validationHelperMock.validateUrlCallsCount)
		XCTAssertEqual(1, credentialManagerMock.saveCredentialToKeychainCallsCount)
		let savedCredential = try XCTUnwrap(credentialManagerMock.saveCredentialToKeychainReceivedCredential)
		XCTAssert(savedCredential.isEqual(expectedUpdatedCredential))
		// Additional check identifier for equality
		XCTAssertEqual(WebDAVCredential.mock.identifier, savedCredential.identifier)
		XCTAssertEqual([savedCredential.identifier], cloudProviderUpdatingMock.providerShouldUpdateWithReceivedInvocations)
	}

	// MARK: - Untrusted Certificate

	func testSaveAccountWithUntrustedCertificate() throws {
		validationHelperMock.validateUrlReturnValue = Promise(untrustedCertificate)
		var verifyClientCallsCount = 0
		viewModel.verifyClient = { _ in
			verifyClientCallsCount += 1
			return Promise(())
		}
		let stateRecorder = viewModel.$state.recordNext(3)
		viewModel.username = "user"
		viewModel.password = "pass"
		viewModel.url = "https://example.com"
		viewModel.saveAccount()

		wait(for: stateRecorder)
		XCTAssertEqual([.initial, .authenticating, .untrustedCertificate(certificate: untrustedCertificate, url: URL(string: "https://example.com")!)], stateRecorder.getElements())

		XCTAssertEqual(0, verifyClientCallsCount)
		XCTAssertEqual(1, validationHelperMock.validateUrlCallsCount)
		XCTAssertFalse(credentialManagerMock.saveCredentialToKeychainCalled)
		XCTAssert(viewModel.showUntrustedCertificateError)
	}

	func testDismissUntrustedCertificateAlert() throws {
		// simulate untrusted certificate flow
		try testSaveAccountWithUntrustedCertificate()

		// simulate dismiss alert
		let stateRecorder = viewModel.$state.recordNext(2)
		viewModel.showUntrustedCertificateError = false
		wait(for: stateRecorder)
		XCTAssertEqual([.untrustedCertificate(certificate: untrustedCertificate, url: URL(string: "https://example.com")!), .initial], stateRecorder.getElements())
	}

	func testSaveAccountWithAllowedUntrustedCertificate() throws {
		// simulate untrusted certificate flow
		try testSaveAccountWithUntrustedCertificate()

		let stateRecorder = viewModel.$state.recordNext(3)
		viewModel.saveAccountWithCertificate()
		wait(for: stateRecorder)
		let expectedStates: [WebDAVAuthenticationViewModel.State] = [.untrustedCertificate(certificate: untrustedCertificate, url: URL(string: "https://example.com")!),
		                                                             .authenticating,
		                                                             .authenticated(.mockWithAllowedCertificate)]
		XCTAssertEqual(expectedStates, stateRecorder.getElements())
	}

	// MARK: - Insecure Connection

	func testSaveAccountWithInsecureConnection() {
		validationHelperMock.validateUrlReturnValue = Promise(trustedCertificate)
		viewModel.verifyClient = { _ in
			self.verifyClientCallsCount += 1
			return Promise(())
		}
		let stateRecorder = viewModel.$state.recordNext(2)
		viewModel.username = "user"
		viewModel.password = "pass"
		viewModel.url = "http://example.com"
		viewModel.saveAccount()

		wait(for: stateRecorder)
		XCTAssertEqual([.initial, .insecureConnectionNotAllowed], stateRecorder.getElements())

		XCTAssertEqual(0, verifyClientCallsCount)
		XCTAssertFalse(validationHelperMock.validateUrlCalled)
		XCTAssertFalse(credentialManagerMock.saveCredentialToKeychainCalled)
		XCTAssert(viewModel.showAllowInsecureConnectionAlert)
	}

	func testDismissInsecureConnectionAlert() {
		// simulate insecure connection flow
		testSaveAccountWithInsecureConnection()

		// simulate dismiss alert
		let stateRecorder = viewModel.$state.recordNext(2)
		viewModel.showAllowInsecureConnectionAlert = false
		wait(for: stateRecorder)
		XCTAssertEqual([.insecureConnectionNotAllowed, .initial], stateRecorder.getElements())
	}

	func testSaveAccountWithAllowedInsecureConnection() throws {
		// simulate insecure connection flow
		testSaveAccountWithInsecureConnection()

		let stateRecorder = viewModel.$state.recordNext(3)
		viewModel.saveAccountWithInsecureConnection()
		wait(for: stateRecorder)
		let expectedStates: [WebDAVAuthenticationViewModel.State] = [.insecureConnectionNotAllowed,
		                                                             .authenticating,
		                                                             .authenticated(.mockWithInsecureConnection)]
		XCTAssertEqual(expectedStates, stateRecorder.getElements())

		XCTAssertEqual(1, verifyClientCallsCount)
		XCTAssertFalse(validationHelperMock.validateUrlCalled)
		XCTAssertEqual(1, credentialManagerMock.saveCredentialToKeychainCallsCount)
		let savedCredential = try XCTUnwrap(credentialManagerMock.saveCredentialToKeychainReceivedCredential)
		XCTAssert(savedCredential.isEqual(.mockWithInsecureConnection))
	}

	func testSaveAccountWithTransformedURL() throws {
		// simulate insecure connection flow
		testSaveAccountWithInsecureConnection()

		let stateRecorder = viewModel.$state.recordNext(3)
		viewModel.saveAccountWithTransformedURL()
		wait(for: stateRecorder)
		let expectedStates: [WebDAVAuthenticationViewModel.State] = [.insecureConnectionNotAllowed,
		                                                             .authenticating,
		                                                             .authenticated(.mock)]
		XCTAssertEqual(expectedStates, stateRecorder.getElements())

		XCTAssertEqual(1, verifyClientCallsCount)
		XCTAssertEqual(1, validationHelperMock.validateUrlCallsCount)
		XCTAssertEqual(1, credentialManagerMock.saveCredentialToKeychainCallsCount)
		let savedCredential = try XCTUnwrap(credentialManagerMock.saveCredentialToKeychainReceivedCredential)
		XCTAssert(savedCredential.isEqual(.mock))
	}
}

private extension WebDAVCredential {
	static let mockCertificate = "Certificate".data(using: .utf8)!
	static let mock = WebDAVCredential(baseURL: URL(string: "https://example.com")!, username: "user", password: "pass", allowedCertificate: nil)
	static let mockWithAllowedCertificate = WebDAVCredential(baseURL: URL(string: "https://example.com")!, username: "user", password: "pass", allowedCertificate: mockCertificate)
	static let mockWithInsecureConnection = WebDAVCredential(baseURL: URL(string: "http://example.com")!, username: "user", password: "pass", allowedCertificate: nil)
}

extension WebDAVAuthenticationViewModel.State: Equatable {
	public static func == (lhs: WebDAVAuthenticationViewModel.State, rhs: WebDAVAuthenticationViewModel.State) -> Bool {
		switch (lhs, rhs) {
		case (.initial, .initial):
			return true
		case (.authenticating, .authenticating):
			return true
		case let (.untrustedCertificate(lhsCertificate, lhsURL), .untrustedCertificate(certificate: rhsCertificate, url: rhsURL)):
			return lhsCertificate == rhsCertificate && lhsURL == rhsURL
		case (.insecureConnectionNotAllowed, .insecureConnectionNotAllowed):
			return true
		case let (.error(lhsError), .error(rhsError)):
			return lhsError as NSError == rhsError as NSError
		case let (.authenticated(lhsCredential), .authenticated(rhsCredential)):
			return lhsCredential.isEqual(rhsCredential)
		default:
			return false
		}
	}
}

extension TLSCertificate: Equatable {
	public static func == (lhs: TLSCertificate, rhs: TLSCertificate) -> Bool {
		return lhs.isTrusted == rhs.isTrusted && lhs.data == rhs.data && lhs.fingerprint == rhs.fingerprint
	}
}

private extension WebDAVCredential {
	func isEqual(_ object: WebDAVCredential) -> Bool {
		return baseURL == object.baseURL && username == object.username && password == object.password && allowedCertificate == object.allowedCertificate
	}
}
