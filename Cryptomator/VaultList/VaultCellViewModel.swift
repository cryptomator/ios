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
import UIKit

protocol VaultCellViewModelProtocol: TableViewCellViewModel, ViewModel {
	var vault: VaultInfo { get }
	var lockButtonIsHidden: AnyPublisher<Bool, Never> { get }
	func lockVault() async throws
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

	func lockVault() async throws {
		let domainIdentifier = NSFileProviderDomainIdentifier(vault.vaultUID)
		do {
			let xpc: XPC<VaultLocking> = try await fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			xpc.proxy.lockVault(domainIdentifier: domainIdentifier)
			vault.vaultIsUnlocked.value = false
		} catch {
			errorPublisher.send(error)
			throw error
		}
	}

	override nonisolated func hash(into hasher: inout Hasher) {
		MainActor.assumeIsolated {
			hasher.combine(vault.vaultUID)
		}
	}

	nonisolated static func == (lhs: VaultCellViewModel, rhs: VaultCellViewModel) -> Bool {
		MainActor.assumeIsolated {
			lhs.vault == rhs.vault
		}
	}
}
