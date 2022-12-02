//
//  MainCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

class MainCoordinator: NSObject, Coordinator, UINavigationControllerDelegate {
	var navigationController: UINavigationController = BaseNavigationController()
	var childCoordinators = [Coordinator]()
	lazy var rootViewController: UISplitViewController = {
		let splitViewController = UISplitViewController()
		splitViewController.preferredDisplayMode = .oneBesideSecondary
		splitViewController.delegate = self
		return splitViewController
	}()

	private weak var lastVaultInfo: VaultInfo?

	func start() {
		let vaultListViewController = VaultListViewController(with: VaultListViewModel())
		vaultListViewController.coordinator = self
		navigationController.viewControllers = [vaultListViewController]
		rootViewController.viewControllers = [
			navigationController,
			EmptyDetailViewController()
		]
	}

	func showOnboarding() {
		let modalNavigationController = OnboardingNavigationController()
		modalNavigationController.isModalInPresentation = true
		let child = OnboardingCoordinator(navigationController: modalNavigationController)
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showTrialExpired() {
		let modalNavigationController = TrialExpiredNavigationController()
		let child = TrialExpiredCoordinator(navigationController: modalNavigationController)
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func addVault() {
		let modalNavigationController = BaseNavigationController()
		let child = AddVaultCoordinator(navigationController: modalNavigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showSettings() {
		let modalNavigationController = BaseNavigationController()
		let child = SettingsCoordinator(navigationController: modalNavigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showVaultDetail(for vaultInfo: VaultInfo) {
		lastVaultInfo = vaultInfo
		let detailNavigationController = BaseNavigationController()
		let child = VaultDetailCoordinator(vaultInfo: vaultInfo, navigationController: detailNavigationController)
		childCoordinators.append(child)
		child.start()
		child.removedVaultDelegate = self
		rootViewController.showDetailViewController(detailNavigationController, sender: nil)
	}

	// MARK: - UINavigationControllerDelegate

	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		// Read the view controller we’re moving from.
		guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
			return
		}

		// Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
		if navigationController.viewControllers.contains(fromViewController) {
			return
		}
	}

	// MARK: - Internal

	private func hideVaultDetail() {
		rootViewController.showDetailViewController(EmptyDetailViewController(), sender: nil)
	}
}

extension MainCoordinator: RemoveVaultDelegate {
	func removedVault(_ vault: VaultInfo) {
		if !rootViewController.isCollapsed, vault == lastVaultInfo {
			hideVaultDetail()
		} else if let navigationController = rootViewController.viewControllers.first as? UINavigationController {
			navigationController.popToRootViewController(animated: true)
		}
		lastVaultInfo = nil
	}
}

extension MainCoordinator: StoreObserverDelegate {
	func purchaseDidSucceed(transaction: PurchaseTransaction) {
		switch transaction {
		case .fullVersion, .yearlySubscription:
			showFullVersionAlert()
		case let .freeTrial(expiresOn):
			showTrialAlert(expirationDate: expiresOn)
		case .unknown:
			break
		}
	}

	private func showFullVersionAlert() {
		showAlert { [weak self] in
			guard let navigationController = self?.navigationController else {
				return
			}
			_ = PurchaseAlert.showForFullVersion(title: LocalizedString.getValue("purchase.unlockedFullVersion.title"), on: navigationController)
		}
	}

	private func showTrialAlert(expirationDate: Date) {
		showAlert { [weak self] in
			guard let navigationController = self?.navigationController else {
				return
			}
			_ = PurchaseAlert.showForTrial(title: LocalizedString.getValue("purchase.beginFreeTrial.alert.title"), expirationDate: expirationDate, on: navigationController)
		}
	}

	private func showAlert(_ showAlertCall: @escaping () -> Void) {
		guard navigationController.presentedViewController == nil else {
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
				self?.showAlert(showAlertCall)
			}
			return
		}
	}
}

extension MainCoordinator: UISplitViewControllerDelegate {
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		return true
	}
}

private class CryptoBotViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .cryptomatorBackground
		let imageView = UIImageView(image: UIImage(named: "bot"))
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(imageView)

		NSLayoutConstraint.activate([
			imageView.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
			imageView.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
			imageView.topAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.topAnchor),
			imageView.bottomAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.bottomAnchor),
			imageView.leadingAnchor.constraint(greaterThanOrEqualTo: view.readableContentGuide.leadingAnchor),
			imageView.trailingAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.trailingAnchor)
		])
	}
}

private class EmptyDetailViewController: BaseNavigationController {
	init() {
		super.init(rootViewController: CryptoBotViewController())
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
