//
//  VaultCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Dependencies
import Promises
import UIKit

protocol VaultCellViewModelProtocol: TableViewCellViewModel, ViewModel {
	var vault: VaultInfo { get }
	var lockButtonIsHidden: AnyPublisher<Bool, Never> { get }
	func lockVault() -> Promise<Void>
	func setVaultUnlockStatus(unlocked: Bool)
}

class VaultCellViewModel: TableViewCellViewModel, VaultCellViewModelProtocol {
	var error: AnyPublisher<Error, Never> {
		return errorPublisher.eraseToAnyPublisher()
	}

	override var type: ConfigurableTableViewCell.Type {
		return VaultCell.self
	}

	var lockButtonIsHidden: AnyPublisher<Bool, Never> {
		return vault.vaultIsUnlocked.$value.map { !$0 }.eraseToAnyPublisher()
	}

	let vault: VaultInfo
	private lazy var errorPublisher = PassthroughSubject<Error, Never>()
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(vault: VaultInfo) {
		self.vault = vault
	}

	func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vault.vaultUID)
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return getXPCPromise.then { xpc in
			xpc.proxy.lockVault(domainIdentifier: domainIdentifier)
		}.then {
			self.setVaultUnlockStatus(unlocked: false)
		}.catch { error in
			self.errorPublisher.send(error)
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	func setVaultUnlockStatus(unlocked: Bool) {
		vault.vaultIsUnlocked.value = unlocked
	}

	override func hash(into hasher: inout Hasher) {
		hasher.combine(vault.vaultUID)
	}

	static func == (lhs: VaultCellViewModel, rhs: VaultCellViewModel) -> Bool {
		return lhs.vault == rhs.vault
	}
}
