import AppAuthCore
import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Dependencies
import SwiftUI
import UIKit

public protocol HubAuthenticationCoordinatorDelegate: AnyObject {
	@MainActor
	func userDidCancelHubAuthentication()

	@MainActor
	func userDismissedHubAuthenticationErrorMessage()
}

public final class HubAuthenticationCoordinator: Coordinator {
	public var childCoordinators = [Coordinator]()
	public var navigationController: UINavigationController
	public weak var parent: Coordinator?

	private let vaultConfig: UnverifiedVaultConfig
	private var progressHUD: ProgressHUD?
	private let unlockHandler: HubVaultUnlockHandler
	@Dependency(\.hubAuthenticationService) var hubAuthenticator
	private weak var delegate: HubAuthenticationCoordinatorDelegate?

	public init(navigationController: UINavigationController,
	            vaultConfig: UnverifiedVaultConfig,
	            unlockHandler: HubVaultUnlockHandler,
	            parent: Coordinator?,
	            delegate: HubAuthenticationCoordinatorDelegate) {
		self.navigationController = navigationController
		self.vaultConfig = vaultConfig
		self.unlockHandler = unlockHandler
		self.parent = parent
		self.delegate = delegate
	}

	public func start() {
		guard let hubConfig = vaultConfig.allegedHubConfig else {
			handleError(HubAuthenticationViewModelError.missingHubConfig, for: navigationController, onOKTapped: { [weak self] in
				guard let self else { return }
				parent?.childDidFinish(self)
			})
			return
		}
		Task { @MainActor in
			do {
				try await checkHostTrust(hubConfig: hubConfig)
			} catch {
				// trust denied or validation failed — already handled in checkHostTrust()
				return
			}
			let authenticator = HubUserAuthenticator(hubAuthenticator: hubAuthenticator, viewController: navigationController)
			let authState: OIDAuthState
			do {
				authState = try await authenticator.authenticate(with: hubConfig)
			} catch let error as NSError where error.domain == OIDGeneralErrorDomain && error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue {
				// do not show alert if user canceled it on purpose
				delegate?.userDidCancelHubAuthentication()
				parent?.childDidFinish(self)
				return
			} catch {
				handleError(error, for: navigationController, onOKTapped: { [weak self] in
					guard let self else { return }
					delegate?.userDismissedHubAuthenticationErrorMessage()
					parent?.childDidFinish(self)
				})
				return
			}
			let viewModel = HubAuthenticationViewModel(authState: authState,
			                                           vaultConfig: vaultConfig,
			                                           unlockHandler: unlockHandler,
			                                           delegate: self)
			await viewModel.continueToAccessCheck()
			guard !viewModel.isLoggedIn else {
				// Do not show the authentication view if the user already authenticated successfully
				return
			}
			navigationController.setNavigationBarHidden(false, animated: false)
			let viewController = HubAuthenticationViewController(viewModel: viewModel)
			navigationController.pushViewController(viewController, animated: true)
		}
	}

	@MainActor
	private func checkHostTrust(hubConfig: HubConfig) async throws {
		guard let vaultBaseURL = getVaultBaseURL() else {
			DDLogError("Hub host trust check failed: unable to extract vault base URL from keyId")
			try await rejectHostTrust(message: LocalizedString.getValue("hubAuthentication.trustHost.error.inconsistentAuthority"))
		}
		let settings = CryptomatorUserDefaults.shared
		let result: HubHostTrustResult
		do {
			result = try HubHostTrustValidator.validate(hubConfig: hubConfig, vaultBaseURL: vaultBaseURL, trustedAuthorities: settings.trustedHubAuthorities)
		} catch {
			DDLogError("Hub host trust validation failed: \(error)")
			try await rejectHostTrust(message: error.localizedDescription)
		}
		switch result {
		case .trusted:
			return
		case let .userConfirmationRequired(untrustedAuthorities):
			let approved = await showTrustHostAlert(untrustedAuthorities: untrustedAuthorities)
			if approved {
				var trusted = settings.trustedHubAuthorities
				trusted.formUnion(untrustedAuthorities)
				settings.trustedHubAuthorities = trusted
			} else {
				delegate?.userDidCancelHubAuthentication()
				parent?.childDidFinish(self)
				throw CancellationError()
			}
		}
	}

	@MainActor
	private func rejectHostTrust(message: String) async throws -> Never {
		await showUntrustedHostAlert(message: message)
		delegate?.userDismissedHubAuthenticationErrorMessage()
		parent?.childDidFinish(self)
		throw CancellationError()
	}

	private static let hubSchemePrefix = "hub+"

	private func getVaultBaseURL() -> URL? {
		guard let keyId = vaultConfig.keyId, keyId.hasPrefix(Self.hubSchemePrefix) else {
			return nil
		}
		let baseURLPath = keyId.deletingPrefix(Self.hubSchemePrefix)
		return URL(string: baseURLPath)
	}

	@MainActor
	private func showTrustHostAlert(untrustedAuthorities: Set<String>) async -> Bool {
		await withCheckedContinuation { continuation in
			let hostList = untrustedAuthorities.sorted().joined(separator: "\n")
			let alertController = UIAlertController(title: LocalizedString.getValue("hubAuthentication.trustHost.alert.title"),
			                                        message: String(format: LocalizedString.getValue("hubAuthentication.trustHost.alert.message"), hostList),
			                                        preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
				continuation.resume(returning: false)
			})
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("hubAuthentication.trustHost.alert.trustButton"), style: .default) { _ in
				continuation.resume(returning: true)
			})
			navigationController.present(alertController, animated: true)
		}
	}

	@MainActor
	private func showUntrustedHostAlert(message: String) async {
		await withCheckedContinuation { continuation in
			let alertController = UIAlertController(title: LocalizedString.getValue("hubAuthentication.untrustedHost.alert.title"),
			                                        message: message,
			                                        preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
				continuation.resume()
			})
			navigationController.present(alertController, animated: true)
		}
	}

	private func showProgressHUD() {
		assert(progressHUD == nil, "showProgressHUD called although one is already shown")
		progressHUD = ProgressHUD()
		progressHUD?.show(presentingViewController: navigationController)
		progressHUD?.showLoadingIndicator()
	}

	private func hideProgressHUD() async {
		await withCheckedContinuation { continuation in
			guard let progressHUD else {
				continuation.resume()
				return
			}
			progressHUD.dismiss(animated: true, completion: { [weak self] in
				continuation.resume()
				self?.progressHUD = nil
			})
		}
	}
}

extension HubAuthenticationCoordinator: HubAuthenticationViewModelDelegate {
	public func hubAuthenticationViewModelWantsToShowLoadingIndicator() {
		showProgressHUD()
	}

	public func hubAuthenticationViewModelWantsToHideLoadingIndicator() async {
		await hideProgressHUD()
	}

	public func hubAuthenticationViewModelWantsToShowNeedsAccountInitAlert(profileURL: URL) {
		let alertController = UIAlertController(title: LocalizedString.getValue("hubAuthentication.requireAccountInit.alert.title"),
		                                        message: LocalizedString.getValue("hubAuthentication.requireAccountInit.alert.message"),
		                                        preferredStyle: .alert)

		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
		let goToProfileAction = UIAlertAction(title: LocalizedString.getValue("hubAuthentication.requireAccountInit.alert.actionButton"),
		                                      style: .default,
		                                      handler: { _ in UIApplication.shared.open(profileURL) })
		alertController.addAction(goToProfileAction)

		navigationController.present(alertController, animated: true)
	}
}
