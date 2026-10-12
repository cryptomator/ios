//
//  HubAuthenticationViewModelTests.swift
//
//
//  Created by Philipp Schmid on 19.11.23.
//

import AppAuthCore
import CryptoKit
import Dependencies
import JOSESwift
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

final class HubAuthenticationViewModelTests: XCTestCase {
	private var unlockHandlerMock: HubVaultUnlockHandlerMock!
	private var delegateMock: HubAuthenticationViewModelDelegateMock!
	private var hubKeyServiceMock: HubKeyReceivingMock!
	private var viewModel: HubAuthenticationViewModel!

	override func setUpWithError() throws {
		unlockHandlerMock = HubVaultUnlockHandlerMock()
		delegateMock = HubAuthenticationViewModelDelegateMock()
		hubKeyServiceMock = HubKeyReceivingMock()

		let unverifiedVaultConfig = try UnverifiedVaultConfig(token: validHubVaultConfig())

		viewModel = HubAuthenticationViewModel(authState: .stub,
		                                       vaultConfig: unverifiedVaultConfig,
		                                       unlockHandler: unlockHandlerMock,
		                                       delegate: delegateMock)
	}

	// MARK: continueToAccessCheck

	func testContinueToAccessCheck_showsLoadingSpinnerWhileReceivingKey() async {
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorCalled)
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorCalled)
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		hubKeyProviderMock.getPrivateKeyReturnValue = P384.KeyAgreement.PrivateKey(compactRepresentable: false)

		let calledReceiveKey = XCTestExpectation()
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigClosure = { _, _ in
			calledReceiveKey.fulfill()
			return try .successMock()
		}

		let calledShowLoadingIndicator = XCTestExpectation()
		delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorClosure = {
			calledShowLoadingIndicator.fulfill()
		}

		let calledHideLoadingIndicator = XCTestExpectation()
		delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorClosure = {
			calledHideLoadingIndicator.fulfill()
		}

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the loading indicator should be displayed while receiving the key
		await fulfillment(of: [calledShowLoadingIndicator, calledReceiveKey, calledHideLoadingIndicator], enforceOrder: true)
	}

	func testContinueToAccessCheck_showsLoadingSpinnerWhileReceivingKeyHidesIfFailed() async {
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorCalled)
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorCalled)
		let calledReceiveKey = XCTestExpectation()
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigClosure = { _, _ in
			calledReceiveKey.fulfill()
			throw TestError()
		}

		let calledShowLoadingIndicator = XCTestExpectation()
		delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorClosure = {
			calledShowLoadingIndicator.fulfill()
		}

		let calledHideLoadingIndicator = XCTestExpectation()
		delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorClosure = {
			calledHideLoadingIndicator.fulfill()
		}

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the loading indicator should be displayed while receiving the key and gets hidden even if the operation fails
		await fulfillment(of: [calledShowLoadingIndicator, calledReceiveKey, calledHideLoadingIndicator], enforceOrder: true)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsActive() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()

		// GIVEN
		// the hub key service returns success with an active Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an active Cryptomator Hub subscription state
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .active)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsInactive() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()

		// GIVEN
		// the hub key service returns success with an inactive Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(legacySubscriptionState: "INACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive Cryptomator Hub subscription state
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsUnknown() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()

		// GIVEN
		// the hub key service returns success with an unknown Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(legacySubscriptionState: "foo")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive Cryptomator Hub subscription state (unknown defaults to inactive)
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateMissing() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()

		// GIVEN
		// the hub key service returns success without a Hub-Subscription-State header
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock()

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive Cryptomator Hub subscription state (missing defaults to inactive)
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
	}

	func testContinueToAccessCheck_iosLicenseValid_takesPrecedenceOverSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		licenseVerifierMock.verifyTokenReturnValue = .valid

		// GIVEN
		// the hub key service returns success with a valid Hub-iOS-License but an inactive legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(iosLicenseToken: "license.jwt.token", legacySubscriptionState: "INACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an active subscription state, ignoring the legacy header
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .active)
		XCTAssertEqual(licenseVerifierMock.verifyTokenReceivedToken, "license.jwt.token")
	}

	func testContinueToAccessCheck_iosLicenseExpired_takesPrecedenceOverSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		licenseVerifierMock.verifyTokenReturnValue = .expired

		// GIVEN
		// the hub key service returns success with an expired Hub-iOS-License but an active legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(iosLicenseToken: "license.jwt.token", legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive subscription state, ignoring the legacy header
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
		XCTAssertEqual(licenseVerifierMock.verifyTokenReceivedToken, "license.jwt.token")
	}

	func testContinueToAccessCheck_iosLicenseInvalidSignature_takesPrecedenceOverSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		licenseVerifierMock.verifyTokenThrowableError = HubLicenseVerificationError.invalidSignature

		// GIVEN
		// the hub key service returns success with a Hub-iOS-License whose signature does not verify, alongside an active legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(iosLicenseToken: "license.jwt.token", legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive subscription state, ignoring the legacy header
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
		XCTAssertNil(viewModel.authenticationFlowState)
	}

	func testContinueToAccessCheck_iosLicenseMalformed_takesPrecedenceOverSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		licenseVerifierMock.verifyTokenThrowableError = HubLicenseVerificationError.malformed

		// GIVEN
		// the hub key service returns success with a malformed Hub-iOS-License but an active legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(iosLicenseToken: "not-a-valid-token", legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive subscription state, ignoring the legacy header
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
		XCTAssertNil(viewModel.authenticationFlowState)
	}

	func testContinueToAccessCheck_iosLicenseEmpty_fallsBackToSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		// set so that a regression which consults the verifier fails on the assertions below instead of trapping
		licenseVerifierMock.verifyTokenReturnValue = .expired

		// GIVEN
		// the hub key service returns success with an empty Hub-iOS-License and an active legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(iosLicenseToken: "", legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the legacy subscription state is used and the license verifier is not consulted
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .active)
		XCTAssertFalse(licenseVerifierMock.verifyTokenCalled)
	}

	func testContinueToAccessCheck_iosLicenseMissing_fallsBackToSubscriptionState() async throws {
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		let licenseVerifierMock = HubLicenseVerifyingMock()
		// set so that a regression which consults the verifier fails on the assertions below instead of trapping
		licenseVerifierMock.verifyTokenReturnValue = .expired

		// GIVEN
		// the hub key service returns success without a Hub-iOS-License but with an active legacy subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(legacySubscriptionState: "ACTIVE")

		hubKeyProviderMock.getPrivateKeyReturnValue = try Self.devicePrivateKey()

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
			$0.cryptomatorHubKeyProvider = hubKeyProviderMock
			$0.hubLicenseVerifier = licenseVerifierMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the legacy subscription state is used and the license verifier is not consulted
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .active)
		XCTAssertFalse(licenseVerifierMock.verifyTokenCalled)
	}

	func testContinueToAccessCheck_accessNotGranted() async {
		// GIVEN
		// the hub key service returns access not granted
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .accessNotGranted

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the authentication flow state is set to accessNotGranted
		XCTAssertEqual(viewModel.authenticationFlowState, .accessNotGranted)
	}

	func testContinueToAccessCheck_needsDeviceRegistration() async {
		// GIVEN
		// the hub key service returns needs device registration
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .needsDeviceRegistration

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the authentication flow state is set to needsDeviceRegistration where the user needs to set the device name
		XCTAssertEqual(viewModel.authenticationFlowState, .deviceRegistration(.deviceName))
	}

	func testContinueToAccessCheck_licenseExceeded() async {
		// GIVEN
		// the hub key service returns that the Cryptomator Hub License is exceeded
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .licenseExceeded

		// WHEN
		// continue the access check
		await withDependencies({
			$0.hubKeyService = hubKeyServiceMock
		}, operation: {
			await self.viewModel.continueToAccessCheck()
		})

		// THEN
		// the authentication flow state is set to licenseExceeded
		XCTAssertEqual(viewModel.authenticationFlowState, .licenseExceeded)
	}

	// MARK: Register

	func testRegister_registersDevice_withName() async {
		let deviceRegisteringMock = HubDeviceRegisteringMock()

		// GIVEN
		// a name has been set by the user
		viewModel.deviceName = "My Device 123"

		// WHEN
		// the user taps on register
		await withDependencies({
			$0.hubDeviceRegisteringService = deviceRegisteringMock
		}, operation: {
			await self.viewModel.register()
		})

		// THEN
		// the registerDevice got called on the device registering servie
		let receivedArguments = deviceRegisteringMock.registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedArguments
		XCTAssertEqual(deviceRegisteringMock.registerDeviceWithNameHubConfigAuthStateSetupCodeCallsCount, 1)
		// with the name set by the user
		XCTAssertEqual(receivedArguments?.name, "My Device 123")
	}

	private struct TestError: Error {}

	private static func devicePrivateKey() throws -> P384.KeyAgreement.PrivateKey {
		let data = try XCTUnwrap(Data(base64Encoded: HubTestFixtures.devicePrivateKey))
		return try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)
	}

	private func validHubVaultConfig() -> Data {
		Data(HubTestFixtures.vaultConfigToken.utf8)
	}

	private func validHubResponseData() -> Data {
		Data("eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJjcnYiOiJQLTM4NCIsImV4dCI6dHJ1ZSwia2V5X29wcyI6W10sImt0eSI6IkVDIiwieCI6Im9DLWlIcDhjZzVsUy1Qd3JjRjZxS0NzbWxfMFJzaEtCV0JJTUYzVjhuTGg2NGlCWTdsX0VsZ3Fjd0JZLXNsR3IiLCJ5IjoiVWozVzdYYVBQakJiMFRwWUFHeXlweVRIR3ByQU1hRXdWTk5Gb05tNEJuNjZuVkNKLU9pUUJYN3RhaVUtby1yWSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ.._r7LC8HLc00jk2SI.ooeI0-E29jryMJ_wbGWKVc_IfHOh3Mlfh5geRYEmLTA4GKHItRYmDdZvGsCj9pJRoNORyHdmlAMxXXIXq_v9ZocoCwZrN7EsaB8A3Kukka35i1sr7kpNbksk3G_COsGRmwQ.GJCKBE-OZ7Nm5RMf_9UwVg".utf8)
	}
}

private extension HubAuthenticationFlow {
	static func successMock(iosLicenseToken: String? = nil, legacySubscriptionState: String? = nil) throws -> HubAuthenticationFlow {
		try .success(.init(encryptedUserKey: .encryptedUserKeyStub(),
		                   encryptedVaultKey: .encryptedVaultKeyStub(),
		                   iosLicenseToken: iosLicenseToken,
		                   legacySubscriptionState: legacySubscriptionState))
	}
}

// MARK: - HubAuthenticationViewModelDelegateMock -

// swiftlint: disable all
final class HubAuthenticationViewModelDelegateMock: HubAuthenticationViewModelDelegate {
	// MARK: - hubAuthenticationViewModelWantsToShowLoadingIndicator

	var hubAuthenticationViewModelWantsToShowLoadingIndicatorCallsCount = 0
	var hubAuthenticationViewModelWantsToShowLoadingIndicatorCalled: Bool {
		hubAuthenticationViewModelWantsToShowLoadingIndicatorCallsCount > 0
	}

	var hubAuthenticationViewModelWantsToShowLoadingIndicatorClosure: (() -> Void)?

	func hubAuthenticationViewModelWantsToShowLoadingIndicator() {
		hubAuthenticationViewModelWantsToShowLoadingIndicatorCallsCount += 1
		hubAuthenticationViewModelWantsToShowLoadingIndicatorClosure?()
	}

	// MARK: - hubAuthenticationViewModelWantsToHideLoadingIndicator

	var hubAuthenticationViewModelWantsToHideLoadingIndicatorCallsCount = 0
	var hubAuthenticationViewModelWantsToHideLoadingIndicatorCalled: Bool {
		hubAuthenticationViewModelWantsToHideLoadingIndicatorCallsCount > 0
	}

	var hubAuthenticationViewModelWantsToHideLoadingIndicatorClosure: (() -> Void)?

	func hubAuthenticationViewModelWantsToHideLoadingIndicator() {
		hubAuthenticationViewModelWantsToHideLoadingIndicatorCallsCount += 1
		hubAuthenticationViewModelWantsToHideLoadingIndicatorClosure?()
	}

	// MARK: - hubAuthenticationViewModelWantsToShowNeedsAccountInitAlert

	var hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLCallsCount = 0
	var hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLCalled: Bool {
		hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLCallsCount > 0
	}

	var hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLReceivedProfileURL: URL?
	var hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLReceivedInvocations: [URL] = []
	var hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLClosure: ((URL) -> Void)?

	func hubAuthenticationViewModelWantsToShowNeedsAccountInitAlert(profileURL: URL) {
		hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLCallsCount += 1
		hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLReceivedProfileURL = profileURL
		hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLReceivedInvocations.append(profileURL)
		hubAuthenticationViewModelWantsToShowNeedsAccountInitAlertProfileURLClosure?(profileURL)
	}
}

// swiftlint: enable all
