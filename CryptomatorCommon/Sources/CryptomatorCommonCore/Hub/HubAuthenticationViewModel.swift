import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import Foundation
import JOSESwift

public enum HubAuthenticationViewModelError: Error {
	case missingHubConfig
	case missingAuthState
}

public class HubAuthenticationViewModel: ObservableObject {
	public enum State: Equatable {
		case userLogin
		case receivedExistingKey
		case accessNotGranted
		case licenseExceeded
		case deviceRegisteredSuccessfully
		case needsDeviceRegistration
		case loading(text: String)
		case error(description: String)
	}

	@Published var authenticationFlowState: State = .userLogin
	@Published public var deviceName: String = ""

	private let vaultConfig: UnverifiedVaultConfig
	private let deviceRegisteringService: HubDeviceRegistering
	private let hubKeyService: HubKeyReceiving
	private let hubUserAuthenticator: HubUserLogin

	private var authState: OIDAuthState?
	private weak var delegate: HubAuthenticationFlowDelegate?

	public init(vaultConfig: UnverifiedVaultConfig,
	            deviceRegisteringService: HubDeviceRegistering = CryptomatorHubAuthenticator.shared,
	            hubUserAuthenticator: HubUserLogin,
	            hubKeyService: HubKeyReceiving = CryptomatorHubAuthenticator.shared,
	            delegate: HubAuthenticationFlowDelegate?) {
		self.vaultConfig = vaultConfig
		self.deviceRegisteringService = deviceRegisteringService
		self.hubUserAuthenticator = hubUserAuthenticator
		self.hubKeyService = hubKeyService
		self.delegate = delegate
	}

	public func login() async {
		guard let hubConfig = vaultConfig.hub else {
			await setStateToErrorState(with: HubAuthenticationViewModelError.missingHubConfig)
			return
		}
		do {
			authState = try await hubUserAuthenticator.authenticate(with: hubConfig)
			await continueToAccessCheck()
		} catch let error as NSError where error.domain == OIDGeneralErrorDomain && error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue {
			// ignore user cancellation
		} catch {
			await setStateToErrorState(with: error)
		}
	}

	public func register() async {
		guard let hubConfig = vaultConfig.hub else {
			await setStateToErrorState(with: HubAuthenticationViewModelError.missingHubConfig)
			return
		}
		guard let authState = authState else {
			await setStateToErrorState(with: HubAuthenticationViewModelError.missingAuthState)
			return
		}

		do {
			try await deviceRegisteringService.registerDevice(withName: deviceName, hubConfig: hubConfig, authState: authState)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		await setState(to: .deviceRegisteredSuccessfully)
	}

	public func refresh() async {
		await continueToAccessCheck()
	}

	public func continueToAccessCheck() async {
		guard let authState = authState else {
			await setStateToErrorState(with: HubAuthenticationViewModelError.missingAuthState)
			return
		}
		await setState(to: .loading(text: "Cryptomator is receiving and processing the response from Hub. Please wait."))

		let authFlow: HubAuthenticationFlow
		do {
			authFlow = try await hubKeyService.receiveKey(authState: authState, vaultConfig: vaultConfig)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		switch authFlow {
		case let .receivedExistingKey(data):
			await receivedExistingKey(data: data)
		case .accessNotGranted:
			await setState(to: .accessNotGranted)
		case .needsDeviceRegistration:
			await setState(to: .needsDeviceRegistration)
		case .licenseExceeded:
			await setState(to: .licenseExceeded)
		}
	}

	private func receivedExistingKey(data: Data) async {
		let privateKey: P384.KeyAgreement.PrivateKey
		let jwe: JWE
		do {
			privateKey = try CryptomatorHubKeyProvider.shared.getPrivateKey()
			jwe = try JWE(compactSerialization: data)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		await delegate?.receivedExistingKey(jwe: jwe, privateKey: privateKey)
	}

	@MainActor
	private func setState(to newState: State) {
		authenticationFlowState = newState
	}

	private func setStateToErrorState(with error: Error) async {
		await setState(to: .error(description: error.localizedDescription))
	}
}
