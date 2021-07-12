//
//  UnlockVaultViewModel.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 05.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import CryptomatorCryptoLib
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
		let kek: [UInt8]
		do {
			let cachedVault = try VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool).getCachedVault(withVaultUID: domain.identifier.rawValue)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			kek = try masterkeyFile.deriveKey(passphrase: password)
		} catch {
			return Promise(error)
		}

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

			return self.proxyUnlockVault(proxy, kek: kek)
		}
	}

	func proxyUnlockVault(_ proxy: VaultUnlocking, kek: [UInt8]) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			proxy.unlockVault(kek: kek, reply: { error in
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
