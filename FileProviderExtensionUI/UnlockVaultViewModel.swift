//
//  UnlockVaultViewModel.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 05.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorFileProvider
import FileProvider
import FileProviderUI
import Foundation
import Promises

class UnlockVaultViewModel {
	var title: String {
		vaultName
	}

	var footerTitle: String {
		return String(format: NSLocalizedString("unlockVault.password.footer", comment: ""), vaultName)
	}

	private let domain: NSFileProviderDomain
	private var vaultName: String {
		return domain.displayName
	}

	init(domain: NSFileProviderDomain) {
		self.domain = domain
	}

	func unlock(withPassword password: String) -> Promise<Void> {
		let url = NSFileProviderManager.default.documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		return wrap { handler in
			FileManager.default.getFileProviderServicesForItem(at: url, completionHandler: handler)
		}.then { services -> Promise<NSXPCConnection?> in
			if let desiredService = services?[VaultUnlockingService.name] {
				return desiredService.getFileProviderConnection()
			} else {
				return Promise(UnlockVaultViewModelError.vaultUnlockingServiceNotSupported)
			}
		}.then { connection -> Promise<Void> in
			guard let connection = connection else {
				throw UnlockVaultViewModelError.connectionIsNil
			}
			connection.remoteObjectInterface = NSXPCInterface(with: VaultUnlocking.self)
			connection.resume()
			let rawProxy = connection.remoteObjectProxyWithErrorHandler { errorAccessingRemoteObject in
				DDLogError("remoteObjectProxyWithErrorHandler failed with: \(errorAccessingRemoteObject)")
			}
			guard let proxy = rawProxy as? VaultUnlocking else {
				throw UnlockVaultViewModelError.rawProxyCastingFailed
			}

			return self.proxyUnlockVault(proxy, password: password)
		}
	}

	func proxyUnlockVault(_ proxy: VaultUnlocking, password: String) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			proxy.unlockVault(password: password, reply: { error in
				if let error = error {
					reject(error)
				} else {
					fulfill(())
				}
			})
		}
	}
}

extension NSFileProviderService {
	func getFileProviderConnection() -> Promise<NSXPCConnection?> {
		wrap { handler in
			self.getFileProviderConnection(completionHandler: handler)
		}
	}
}

enum UnlockVaultViewModelError: Error {
	case vaultUnlockingServiceNotSupported
	case rawProxyCastingFailed
	case connectionIsNil
}
