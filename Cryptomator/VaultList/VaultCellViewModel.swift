//
//  VaultCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
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
		return lockButtonIsHiddenPublisher.eraseToAnyPublisher()
	}

	let vault: VaultInfo
	private lazy var lockButtonIsHiddenPublisher = CurrentValueSubject<Bool, Never>(!vault.vaultIsUnlocked)
	private lazy var errorPublisher = PassthroughSubject<Error, Never>()
	private let fileProviderConnector: FileProviderConnector

	init(vault: VaultInfo, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.vault = vault
		self.fileProviderConnector = fileProviderConnector
	}

	func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vault.vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy in
			proxy.lockVault(domainIdentifier: domainIdentifier)
		}.then {
			self.setVaultUnlockStatus(unlocked: false)
		}.catch { error in
			self.errorPublisher.send(error)
		}
	}

	func setVaultUnlockStatus(unlocked: Bool) {
		vault.vaultIsUnlocked = unlocked
		lockButtonIsHiddenPublisher.send(!unlocked)
	}

	override func hash(into hasher: inout Hasher) {
		hasher.combine(vault)
	}

	static func == (lhs: VaultCellViewModel, rhs: VaultCellViewModel) -> Bool {
		return lhs.vault == rhs.vault
	}
}
