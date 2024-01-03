//
//  HubAuthenticationViewModelTests.swift
//
//
//  Created by Philipp Schmid on 19.11.23.
//

import AppAuthCore
import CryptoKit
import JOSESwift
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib
@testable import Dependencies

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

	func testContinueToAccessCheck_showsLoadingSpinnerWhileReceivingKey() async throws {
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorCalled)
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorCalled)
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		DependencyValues.mockDependency(\.cryptomatorHubKeyProvider, with: hubKeyProviderMock)
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
		await viewModel.continueToAccessCheck()

		// THEN
		// the loading indicator should be displayed while receiving the key
		await fulfillment(of: [calledShowLoadingIndicator, calledReceiveKey, calledHideLoadingIndicator], enforceOrder: true)
	}

	func testContinueToAccessCheck_showsLoadingSpinnerWhileReceivingKeyHidesIfFailed() async throws {
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToShowLoadingIndicatorCalled)
		XCTAssertFalse(delegateMock.hubAuthenticationViewModelWantsToHideLoadingIndicatorCalled)
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)
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
		await viewModel.continueToAccessCheck()

		// THEN
		// the loading indicator should be displayed while receiving the key and gets hidden even if the operation fails
		await fulfillment(of: [calledShowLoadingIndicator, calledReceiveKey, calledHideLoadingIndicator], enforceOrder: true)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsActive() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		DependencyValues.mockDependency(\.cryptomatorHubKeyProvider, with: hubKeyProviderMock)

		// GIVEN
		// the hub key service returns success with an active Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(header: ["hub-subscription-state": "ACTIVE"])

		let devicePrivKey = "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDB2bmFCWy2p+EbAn8NWS5Om+GA7c5LHhRZb8g2pSMSf0fsd7k7dZDVrnyHFiLdd/YGhZANiAAR6bsjTEdXKWIuu1Bvj6Y8wySlIROy7YpmVZTY128ItovCD8pcR4PnFljvAIb2MshCdr1alX4g6cgDOqcTeREiObcSfucOU9Ry1pJ/GnX6KA0eSljrk6rxjSDos8aiZ6Mg="
		let data = Data(base64Encoded: devicePrivKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)
		hubKeyProviderMock.getPrivateKeyReturnValue = privateKey

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an active Cryptomator Hub subscription state
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .active)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsInactive() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		DependencyValues.mockDependency(\.cryptomatorHubKeyProvider, with: hubKeyProviderMock)

		// GIVEN
		// the hub key service returns success with an active Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(header: ["hub-subscription-state": "INACTIVE"])

		let devicePrivKey = "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDB2bmFCWy2p+EbAn8NWS5Om+GA7c5LHhRZb8g2pSMSf0fsd7k7dZDVrnyHFiLdd/YGhZANiAAR6bsjTEdXKWIuu1Bvj6Y8wySlIROy7YpmVZTY128ItovCD8pcR4PnFljvAIb2MshCdr1alX4g6cgDOqcTeREiObcSfucOU9Ry1pJ/GnX6KA0eSljrk6rxjSDos8aiZ6Mg="
		let data = Data(base64Encoded: devicePrivKey)!
		let privateKey = try P384.KeyAgreement.PrivateKey(pkcs8DerRepresentation: data)
		hubKeyProviderMock.getPrivateKeyReturnValue = privateKey

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the unlock handler gets informed about the successful remote unlock with an inactive Cryptomator Hub subscription state
		let receivedResponse = unlockHandlerMock.didSuccessfullyRemoteUnlockReceivedResponse
		XCTAssertEqual(unlockHandlerMock.didSuccessfullyRemoteUnlockCallsCount, 1)
		XCTAssertEqual(receivedResponse?.subscriptionState, .inactive)
	}

	func testContinueToAccessCheck_success_hubSubscriptionStateIsUnknown() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)
		let hubKeyProviderMock = CryptomatorHubKeyProviderMock()
		DependencyValues.mockDependency(\.cryptomatorHubKeyProvider, with: hubKeyProviderMock)

		// GIVEN
		// the hub key service returns success with an unknown Cryptomator Hub subscription state
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = try .successMock(header: ["hub-subscription-state": "foo"])
		hubKeyProviderMock.getPrivateKeyReturnValue = P384.KeyAgreement.PrivateKey(compactRepresentable: false)

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the unlock handler gets not informed about a successful remote unlock
		XCTAssertFalse(unlockHandlerMock.didSuccessfullyRemoteUnlockCalled)
		// the user gets informed about the error
		let currentAuthenticationFlowState = try XCTUnwrap(viewModel.authenticationFlowState)
		XCTAssert(currentAuthenticationFlowState.isError)
	}

	func testContinueToAccessCheck_accessNotGranted() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)

		// GIVEN
		// the hub key service returns access not granted
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .accessNotGranted

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the authentication flow state is set to accessNotGranted
		XCTAssertEqual(viewModel.authenticationFlowState, .accessNotGranted)
	}

	func testContinueToAccessCheck_needsDeviceRegistration() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)

		// GIVEN
		// the hub key service returns needs device registration
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .needsDeviceRegistration

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the authentication flow state is set to needsDeviceRegistration where the user needs to set the device name
		XCTAssertEqual(viewModel.authenticationFlowState, .deviceRegistration(.deviceName))
	}

	func testContinueToAccessCheck_licenseExceeded() async throws {
		DependencyValues.mockDependency(\.hubKeyService, with: hubKeyServiceMock)

		// GIVEN
		// the hub key service returns that the Cryptomator Hub License is exceeded
		hubKeyServiceMock.receiveKeyAuthStateVaultConfigReturnValue = .licenseExceeded

		// WHEN
		// continue the access check
		await viewModel.continueToAccessCheck()

		// THEN
		// the authentication flow state is set to licenseExceeded
		XCTAssertEqual(viewModel.authenticationFlowState, .licenseExceeded)
	}

	// MARK: Register

	func testRegister_registersDevice_withName() async {
		let deviceRegisteringMock = HubDeviceRegisteringMock()
		DependencyValues.mockDependency(\.hubDeviceRegisteringService, with: deviceRegisteringMock)

		// GIVEN
		// a name has been set by the user
		viewModel.deviceName = "My Device 123"

		// WHEN
		// the user taps on register
		await viewModel.register()

		// THEN
		// the registerDevice got called on the device registering servie
		let receivedArguments = deviceRegisteringMock.registerDeviceWithNameHubConfigAuthStateSetupCodeReceivedArguments
		XCTAssertEqual(deviceRegisteringMock.registerDeviceWithNameHubConfigAuthStateSetupCodeCallsCount, 1)
		// with the name set by the user
		XCTAssertEqual(receivedArguments?.name, "My Device 123")
	}

	private struct TestError: Error {}

	private func validHubVaultConfig() -> Data {
		"eyJraWQiOiJodWIraHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBpL3ZhdWx0cy83NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJ0eXAiOiJqd3QiLCJhbGciOiJIUzI1NiIsImh1YiI6eyJjbGllbnRJZCI6ImNyeXB0b21hdG9yIiwiYXV0aEVuZHBvaW50IjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcva2MvcmVhbG1zL2h1YjMwL3Byb3RvY29sL29wZW5pZC1jb25uZWN0L2F1dGgiLCJ0b2tlbkVuZHBvaW50IjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcva2MvcmVhbG1zL2h1YjMwL3Byb3RvY29sL29wZW5pZC1jb25uZWN0L3Rva2VuIiwiYXV0aFN1Y2Nlc3NVcmwiOiJodHRwczovL3Rlc3RpbmcuaHViLmNyeXB0b21hdG9yLm9yZy9odWIzMC9hcHAvdW5sb2NrLXN1Y2Nlc3M_dmF1bHQ9NzVhZjIxYjctNDg0OS00NTU4LWIwNWMtZGU2ZGM5MDc3YTY3IiwiYXV0aEVycm9yVXJsIjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBwL3VubG9jay1lcnJvcj92YXVsdD03NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJhcGlCYXNlVXJsIjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBpLyIsImRldmljZXNSZXNvdXJjZVVybCI6Imh0dHBzOi8vdGVzdGluZy5odWIuY3J5cHRvbWF0b3Iub3JnL2h1YjMwL2FwaS9kZXZpY2VzLyJ9fQ.eyJqdGkiOiI3NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJmb3JtYXQiOjgsImNpcGhlckNvbWJvIjoiU0lWX0dDTSIsInNob3J0ZW5pbmdUaHJlc2hvbGQiOjIyMH0.Z0x_5D073zo3smZq5q5wgDRheewcapCrIqg_0iD5qwM".data(using: .utf8)!
	}

	private func validHubResponseData() -> Data {
		"eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJjcnYiOiJQLTM4NCIsImV4dCI6dHJ1ZSwia2V5X29wcyI6W10sImt0eSI6IkVDIiwieCI6Im9DLWlIcDhjZzVsUy1Qd3JjRjZxS0NzbWxfMFJzaEtCV0JJTUYzVjhuTGg2NGlCWTdsX0VsZ3Fjd0JZLXNsR3IiLCJ5IjoiVWozVzdYYVBQakJiMFRwWUFHeXlweVRIR3ByQU1hRXdWTk5Gb05tNEJuNjZuVkNKLU9pUUJYN3RhaVUtby1yWSJ9LCJhcHUiOiIiLCJhcHYiOiIifQ.._r7LC8HLc00jk2SI.ooeI0-E29jryMJ_wbGWKVc_IfHOh3Mlfh5geRYEmLTA4GKHItRYmDdZvGsCj9pJRoNORyHdmlAMxXXIXq_v9ZocoCwZrN7EsaB8A3Kukka35i1sr7kpNbksk3G_COsGRmwQ.GJCKBE-OZ7Nm5RMf_9UwVg".data(using: .utf8)!
	}
}

private extension OIDAuthState {
	static var stub: Self {
		.init(authorizationResponse: .init(request: .init(configuration: .init(authorizationEndpoint: URL(string: "example.com")!, tokenEndpoint: URL(string: "example.com")!), clientId: "", scopes: nil, redirectURL: URL(string: "example.com")!, responseType: "code", additionalParameters: nil), parameters: [:]))
	}
}

private extension HubAuthenticationViewModel.State {
	var isError: Bool {
		switch self {
		case .error:
			return true
		default:
			return false
		}
	}
}

private extension JWE {
	static func encryptedUserKeyStub() throws -> JWE {
		try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrZXlfb3BzIjpbXSwiZXh0Ijp\
		0cnVlLCJrdHkiOiJFQyIsIngiOiJoeHpiSWh6SUJza3A5ZkZFUmJSQ2RfOU1fbWYxNElqaDZhcnNoVX\
		NkcEEyWno5ejZZNUs4NHpZR2I4b2FHemNUIiwieSI6ImJrMGRaNWhpelZ0TF9hN2hNejBjTUduNjhIR\
		jZFdWlyNHdlclNkTFV5QWd2NWUzVzNYSG5sdHJ2VlRyU3pzUWYiLCJjcnYiOiJQLTM4NCJ9LCJhcHUi\
		OiIiLCJhcHYiOiIifQ..pu3Q1nR_yvgRAapG.4zW0xm0JPxbcvZ66R-Mn3k841lHelDQfaUvsZZAtWs\
		L2w4FMi6H_uu6ArAWYLtNREa_zfcPuyuJsFferYPSNRUWt4OW6aWs-l_wfo7G1ceEVxztQXzQiwD30U\
		TA8OOdPcUuFfEq2-d9217jezrcyO6m6FjyssEZIrnRArUPWKzGdghXccGkkf0LTZcGJoHeKal-RtyP8\
		PfvEAWTjSOCpBlSdUJ-1JL3tyd97uVFNaVuH3i7vvcMoUP_bdr0XW3rvRgaeC6X4daPLUvR1hK5Msut\
		QMtM2vpFghS_zZxIQRqz3B2ECxa9Bjxhmn8kLX5heZ8fq3lH-bmJp1DxzZ4V1RkWk.yVwXG9yARa5Ih\
		q2koh2NbQ
		""")
	}

	static func encryptedVaultKeyStub() throws -> JWE {
		try JWE(compactSerialization: """
		eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6ImNZdlVFZm9LYkJjenZySE5zQjUxOGpycUxPMGJDOW5lZjR4NzFFMUQ5dk95MXRqd1piZzV3cFI0OE5nU1RQdHgiLCJ5IjoiaWRJekhCWERzSzR2NTZEeU9yczJOcDZsSG1zb29fMXV0VTlzX3JNdVVkbkxuVXIzUXdLZkhYMWdaVXREM1RKayJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..0VZqu5ei9U3blGtq.eDvhU6drw7mIwvXu6Q.f05QnhI7JWG3IYHvexwdFQ
		""")
	}
}

private extension HubAuthenticationFlow {
	static func successMock(header: [AnyHashable: Any] = [:]) throws -> HubAuthenticationFlow {
		try .success(.init(encryptedUserKey: .encryptedUserKeyStub(),
		                   encryptedVaultKey: .encryptedVaultKeyStub(),
		                   header: header))
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
