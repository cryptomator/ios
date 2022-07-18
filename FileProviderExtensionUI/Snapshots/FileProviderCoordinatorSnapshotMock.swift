//
//  FileProviderCoordinatorSnapshotMock.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 14.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if SNAPSHOTS
import CryptomatorCommonCore
import FileProviderUI
import LocalAuthentication
import Promises
import UIKit

class FileProviderCoordinatorSnapshotMock: FileProviderCoordinator {
	override init(extensionContext: FPUIActionExtensionContext, hostViewController: UIViewController) {
		UnlockVaultViewController.changeUnlock
		UnlockVaultViewController.setSnapshotAccessibilityIdentifier
		UITextField.changePasswordFielCell
		super.init(extensionContext: extensionContext, hostViewController: hostViewController)
	}

	override func showManualPasswordScreen(viewModel: UnlockVaultViewModel) {
		let viewModel = UnlockVaultViewModelSnapshotMock(domain: NSFileProviderDomain(vaultUID: "123", displayName: ""))
		let unlockVaultVC = UnlockVaultViewController(viewModel: viewModel)
		unlockVaultVC.coordinator = self
		navigationController.pushViewController(unlockVaultVC, animated: false)
	}
}

class UnlockVaultViewModelSnapshotMock: UnlockVaultViewModel {
	init(domain: NSFileProviderDomain) {
		super.init(domain: domain,
		           wrongBiometricalPassword: false,
		           fileProviderConnector: FileProviderXPCConnector.shared,
		           passwordManager: VaultPasswordManagerSnapshotMock(),
		           vaultAccountManager: VaultAccountDBManager.shared,
		           providerManager: CloudProviderDBManager.shared,
		           vaultCache: VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool))
	}
}

class VaultPasswordManagerSnapshotMock: VaultPasswordManager {
	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {}

	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		return ""
	}

	func removePassword(forVaultUID vaultUID: String) throws {}

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		return true
	}
}

extension UnlockVaultViewController {
	static let changeUnlock: Void = {
		guard let originalMethod = class_getInstanceMethod(UnlockVaultViewController.self, #selector(unlock)),
		      let swizzledMethod = class_getInstanceMethod(UnlockVaultViewController.self, #selector(swizzled_unlock))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_unlock() {
		let getXPCPromise: Promise<XPC<VaultUnlocking>> = FileProviderXPCConnector.shared.getXPC(serviceName: .vaultUnlocking, domain: nil)
		getXPCPromise.then { xpc in
			xpc.proxy.unlockVault(kek: [UInt8](), reply: { [weak self] _ in
				self?.coordinator?.done()
			})
		}
	}

	static let setSnapshotAccessibilityIdentifier: Void = {
		guard let originalMethod = class_getInstanceMethod(UnlockVaultViewController.self, #selector(viewDidLoad)),
		      let swizzledMethod = class_getInstanceMethod(UnlockVaultViewController.self, #selector(swizzled_viewDidLoad))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_viewDidLoad() {
		swizzled_viewDidLoad()
		tableView.accessibilityIdentifier = "Snapshot_\(String(describing: type(of: self)))"
		navigationItem.rightBarButtonItem?.accessibilityIdentifier = "Snapshot_UnlockButton"
	}
}

extension UITextField {
	static let changePasswordFielCell: Void = {
		guard let originalMethod = class_getInstanceMethod(UITextField.self, #selector(layoutSubviews)),
		      let swizzledMethod = class_getInstanceMethod(UITextField.self, #selector(swizzled_layoutSubviews))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_layoutSubviews() {
		swizzled_layoutSubviews()
		isSecureTextEntry = false
	}
}
#endif
