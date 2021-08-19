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
import LocalAuthentication
import Promises

enum AuthenticationError: Error {
	case authenticationFailedWithoutError
}

enum UnlockCellType: Int {
	case password
	case biometricalUnlock
	case enableBiometricalUnlock
	case unknown
}

enum UnlockVaultViewModelError: Error {
	case vaultUnlockingServiceNotSupported
	case rawProxyCastingFailed
	case connectionIsNil
}

enum UnlockSection: Int {
	case passwordSection
	case biometricalUnlockSection
	case enableBiometricalSection
}

class UnlockVaultViewModel {
	var title: String {
		vaultName
	}

	var numberOfSections: Int {
		return sections.count
	}

	var biometricalUnlockEnabled: Bool {
		do {
			return try passwordManager.hasPassword(forVaultUID: vaultUID)
		} catch {
			DDLogError("biometricalUnlockEnabled failed with error: \(error)")
			return false
		}
	}

	private let domain: NSFileProviderDomain
	private var vaultName: String {
		return domain.displayName
	}

	private var vaultUID: String {
		return domain.identifier.rawValue
	}

	private var sections: [UnlockSection] {
		if canEvaluatePolicy {
			if biometricalUnlockEnabled {
				return [.passwordSection, .biometricalUnlockSection]

			} else {
				return [.passwordSection, .enableBiometricalSection]
			}
		} else {
			return [.passwordSection]
		}
	}

	private let cells: [UnlockSection: [UnlockCellType]] = [
		.passwordSection: [.password],
		.biometricalUnlockSection: [.biometricalUnlock],
		.enableBiometricalSection: [.enableBiometricalUnlock]
	]

	private let context: LAContext
	private let passwordManager: VaultPasswordKeychainManager
	private lazy var canEvaluatePolicy: Bool = {
		var error: NSError?
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			return true
		} else {
			DDLogError("Can not evaluate policy due to error: \(error?.description ?? "")")
			return false
		}
	}()

	private let fileProviderConnector: FileProviderConnector

	init(domain: NSFileProviderDomain, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.domain = domain
		self.fileProviderConnector = fileProviderConnector
		let context = LAContext()
		// Remove fallback title because "Enter password" also closes the FileProviderExtensionUI and does not display the password input
		context.localizedFallbackTitle = ""
		self.context = context
		self.passwordManager = VaultPasswordKeychainManager()
	}

	func numberOfRows(in section: Int) -> Int {
		let unlockSection = sections[section]
		if let sectionCells = cells[unlockSection] {
			return sectionCells.count
		} else {
			return 0
		}
	}

	func getCellType(for indexPath: IndexPath) -> UnlockCellType {
		let unlockSection = sections[indexPath.section]
		guard let sectionCells = cells[unlockSection] else {
			return .unknown
		}
		return sectionCells[indexPath.row]
	}

	func getTitle(for indexPath: IndexPath) -> String? {
		switch getCellType(for: indexPath) {
		case .biometricalUnlock:
			return getUnlockTitle(for: context.biometryType)
		case .enableBiometricalUnlock:
			return getEnableTitle(for: context.biometryType)
		default:
			return nil
		}
	}

	func getSystemImageName(for indexPath: IndexPath) -> String? {
		switch getCellType(for: indexPath) {
		case .biometricalUnlock:
			return getSystemImageName(for: context.biometryType)
		default:
			return nil
		}
	}

	func getFooterTitle(for section: Int) -> String? {
		let unlockSection = sections[section]
		switch unlockSection {
		case .passwordSection:
			return String(format: LocalizedString.getValue("unlockVault.password.footer"), vaultName)
		case .enableBiometricalSection:
			guard let biometryTypeName = getName(for: context.biometryType) else {
				return nil
			}
			return String(format: LocalizedString.getValue("unlockVault.enableBiometricalUnlock.footer"), biometryTypeName)
		default:
			return nil
		}
	}

	// MARK: Unlock Vault

	func unlock(withPassword password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let kek: [UInt8]
		do {
			let cachedVault = try VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool).getCachedVault(withVaultUID: vaultUID)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			kek = try masterkeyFile.deriveKey(passphrase: password)
		} catch {
			return Promise(error)
		}
		return fileProviderConnector.getProxy(serviceName: VaultUnlockingService.name, domain: domain).then { proxy -> Promise<Void> in
			return self.proxyUnlockVault(proxy, kek: kek)
		}.then {
			if storePasswordInKeychain {
				do {
					try self.passwordManager.setPassword(password, forVaultUID: self.vaultUID)
				} catch {
					throw error
				}
			}
		}
	}

	/**
	 Unlock a vault via Touch ID or Face ID.

	 Since the closing of the evaluate policy dialog causes the FileProviderExtensionUI view to be closed,
	 some actions need special handling.
	 These include that if successful, a subsequent `enumerateItems` call is executed too quickly and the `FileProviderAdapter` is not yet available. Therefore, we need to artificially delay the item enumeration until we have successfully completed our actual vault unlock.
	 This means we have to notify the proxy about the start (to enable the artificial delay) and the end of a biometric unlock (to disable the artificial delay again - otherwise the user will not see an authenticate dialog in the Files app).
	 */
	func biometricalUnlock() -> Promise<Void> {
		let reason = LocalizedString.getValue("unlockVault.evaluatePolicy.reason")
		let getProxyPromise: Promise<VaultUnlocking> = fileProviderConnector.getProxy(serviceName: VaultUnlockingService.name, domain: domain) // getProxy()
		return getProxyPromise.then { proxy in
			proxy.startBiometricalUnlock()
		}.then { _ -> Void in
			var error: NSError?
			guard self.context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
				if let error = error {
					throw error
				} else {
					throw AuthenticationError.authenticationFailedWithoutError
				}
			}
		}.then {
			self.context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
		}.then {
			getProxyPromise
		}.then(on: .main) { proxy in
			self.unlockWithSavedPassword(proxy: proxy)
		}.always {
			getProxyPromise.then { proxy in
				proxy.endBiometricalUnlock()
			}
		}
	}

	// MARK: Internal

	private func getUnlockTitle(for biometryType: LABiometryType) -> String? {
		guard let biometryName = getName(for: biometryType) else {
			return nil
		}
		return String(format: LocalizedString.getValue("unlockVault.button.unlockVia"), biometryName)
	}

	private func getEnableTitle(for biometryType: LABiometryType) -> String? {
		guard let biometryName = getName(for: biometryType) else {
			return nil
		}
		return String(format: LocalizedString.getValue("unlockVault.enableBiometricalUnlock.switch"), biometryName)
	}

	private func getSystemImageName(for biometryType: LABiometryType) -> String? {
		switch biometryType {
		case .faceID:
			return "faceid"
		case .touchID:
			return "touchid"
		default:
			return nil
		}
	}

	private func getName(for biometryType: LABiometryType) -> String? {
		switch biometryType {
		case .faceID:
			return LocalizedString.getValue("biometryType.faceID")
		case .touchID:
			return LocalizedString.getValue("biometryType.touchID")
		default:
			return nil
		}
	}

	private func unlockWithSavedPassword(proxy: VaultUnlocking) -> Promise<Void> {
		let password: String
		do {
			password = try passwordManager.getPassword(forVaultUID: vaultUID, context: context)
		} catch {
			return Promise(error)
		}
		let kek: [UInt8]
		do {
			let cachedVault = try VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool).getCachedVault(withVaultUID: vaultUID)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			kek = try masterkeyFile.deriveKey(passphrase: password)
		} catch {
			return Promise(error)
		}
		return proxyUnlockVault(proxy, kek: kek)
	}

	private func proxyUnlockVault(_ proxy: VaultUnlocking, kek: [UInt8]) -> Promise<Void> {
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

extension LAContext {
	func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			self.evaluatePolicy(policy, localizedReason: localizedReason) { success, error in
				if success {
					fulfill(())
				} else {
					if let error = error {
						reject(error)
					} else {
						reject(AuthenticationError.authenticationFailedWithoutError)
					}
				}
			}
		}
	}
}
