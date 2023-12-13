import AppAuthCore
import CocoaLumberjackSwift
import CryptoKit
import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import JOSESwift
import UIKit

public enum HubAuthenticationViewModelError: Error {
	case missingHubConfig
	case missingAuthState
	case missingSubscriptionHeader
	case unexpectedSubscriptionHeader
}

public protocol HubAuthenticationViewModelDelegate: AnyObject {
	@MainActor
	func hubAuthenticationViewModelWantsToShowLoadingIndicator()

	@MainActor
	func hubAuthenticationViewModelWantsToHideLoadingIndicator() async

	@MainActor
	func hubAuthenticationViewModelWantsToShowNeedsAccountInitAlert(profileURL: URL)
}

public final class HubAuthenticationViewModel: ObservableObject {
	public enum State: Equatable {
		case accessNotGranted
		case licenseExceeded
		case deviceRegistration(DeviceRegistration)
		case error(description: String)
	}

	public enum DeviceRegistration: Equatable {
		case deviceName
		case needsAuthorization
	}

	private enum Constants {
		static var subscriptionState: String { "hub-subscription-state" }
	}

	@Published var authenticationFlowState: State?
	@Published public var deviceName: String = UIDevice.current.name
	private(set) var isLoggedIn = false

	private let vaultConfig: UnverifiedVaultConfig
	private let authState: OIDAuthState
	private let unlockHandler: HubVaultUnlockHandler
	@Dependency(\.hubDeviceRegisteringService) var deviceRegisteringService
	@Dependency(\.hubKeyService) var hubKeyService
	@Dependency(\.cryptomatorHubKeyProvider) var cryptomatorHubKeyProvider
	private weak var delegate: HubAuthenticationViewModelDelegate?

	public init(authState: OIDAuthState,
	            vaultConfig: UnverifiedVaultConfig,
	            unlockHandler: HubVaultUnlockHandler,
	            delegate: HubAuthenticationViewModelDelegate) {
		self.authState = authState
		self.vaultConfig = vaultConfig
		self.unlockHandler = unlockHandler
		self.delegate = delegate
	}

	public func register() async {
		guard let hubConfig = vaultConfig.allegedHubConfig else {
			await setStateToErrorState(with: HubAuthenticationViewModelError.missingHubConfig)
			return
		}

		do {
			try await deviceRegisteringService.registerDevice(withName: deviceName, hubConfig: hubConfig, authState: authState)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		await setState(to: .deviceRegistration(.needsAuthorization))
	}

	public func refresh() async {
		await continueToAccessCheck()
	}

	public func continueToAccessCheck() async {
		await delegate?.hubAuthenticationViewModelWantsToShowLoadingIndicator()

		let authFlow: HubAuthenticationFlow
		do {
			authFlow = try await hubKeyService.receiveKey(authState: authState, vaultConfig: vaultConfig)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		await delegate?.hubAuthenticationViewModelWantsToHideLoadingIndicator()

		switch authFlow {
		case let .success(data, header):
			await receivedExistingKey(data: data, header: header)
		case .accessNotGranted:
			await setState(to: .accessNotGranted)
		case .needsDeviceRegistration:
			await setState(to: .deviceRegistration(.deviceName))
		case .licenseExceeded:
			await setState(to: .licenseExceeded)
		case let .requiresAccountInitialization(profileURL):
			await delegate?.hubAuthenticationViewModelWantsToShowNeedsAccountInitAlert(profileURL: profileURL)
		}
	}

	private func receivedExistingKey(data: Data, header: [AnyHashable: Any]) async {
		let privateKey: P384.KeyAgreement.PrivateKey
		let jwe: JWE
		let subscriptionState: HubSubscriptionState
		do {
			privateKey = try cryptomatorHubKeyProvider.getPrivateKey()
			jwe = try JWE(compactSerialization: data)
			subscriptionState = try getSubscriptionState(from: header)
		} catch {
			await setStateToErrorState(with: error)
			return
		}
		let response = HubUnlockResponse(jwe: jwe,
		                                 privateKey: privateKey,
		                                 subscriptionState: subscriptionState)
		await MainActor.run { isLoggedIn = true }
		await unlockHandler.didSuccessfullyRemoteUnlock(response)
	}

	@MainActor
	private func setState(to newState: State) {
		authenticationFlowState = newState
	}

	private func setStateToErrorState(with error: Error) async {
		await delegate?.hubAuthenticationViewModelWantsToHideLoadingIndicator()
		await setState(to: .error(description: error.localizedDescription))
	}

	private func getSubscriptionState(from header: [AnyHashable: Any]) throws -> HubSubscriptionState {
		guard let subscriptionStateValue = header[Constants.subscriptionState] as? String else {
			DDLogError("Can't retrieve hub subscription state from header -> missing value")
			throw HubAuthenticationViewModelError.missingSubscriptionHeader
		}
		switch subscriptionStateValue {
		case "ACTIVE":
			return .active
		case "INACTIVE":
			return .inactive
		default:
			DDLogError("Can't retrieve hub subscription state from header -> unexpected value")
			throw HubAuthenticationViewModelError.unexpectedSubscriptionHeader
		}
	}
}
