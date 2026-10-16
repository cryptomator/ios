//
//  VaultListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import GRDB

class VaultListViewModel: ViewModel, VaultListViewModelProtocol {
	var error: AnyPublisher<Error, Never> {
		errorPublisher.eraseToAnyPublisher()
	}

	let headerTitle = LocalizedString.getValue("vaultList.header.title")
	let emptyListMessage = LocalizedString.getValue("vaultList.emptyList.message")
	let removeAlert = ListViewModelAlertContent(title: LocalizedString.getValue("vaultList.remove.alert.title"),
	                                            message: LocalizedString.getValue("vaultList.remove.alert.message"),
	                                            confirmButtonText: LocalizedString.getValue("common.button.remove"))
	var vaultCellViewModels: [VaultCellViewModel]
	private let dbManager: DatabaseManager
	private let vaultManager: VaultDBManager
	@Dependency(\.fileProviderConnector) private var fileProviderConnector
	private var observation: DatabaseCancellable?
	private lazy var subscribers = Set<AnyCancellable>()
	private lazy var errorPublisher = PassthroughSubject<Error, Never>()
	private lazy var databaseChangedPublisher = CurrentValueSubject<Result<[TableViewCellViewModel], Error>, Never>(.success([]))
	private var removedRow = false

	convenience init() {
		self.init(dbManager: DatabaseManager.shared, vaultManager: VaultDBManager.shared)
	}

	init(dbManager: DatabaseManager, vaultManager: VaultDBManager) {
		self.dbManager = dbManager
		self.vaultManager = vaultManager
		self.vaultCellViewModels = [VaultCellViewModel]()
	}

	func startListenForChanges() -> AnyPublisher<Result<[TableViewCellViewModel], Error>, Never> {
		observation = dbManager.observeVaultAccounts(onError: { error in
			DDLogError("Observe vault accounts failed with error: \(error)")
			self.databaseChangedPublisher.send(.failure(error))
		}, onChange: { _ in
			do {
				try self.refreshItems()
				self.startRefreshingVaultLockStates()
				if !self.removedRow {
					self.databaseChangedPublisher.send(.success(self.vaultCellViewModels))
				}
			} catch {
				DDLogError("RefreshItems failed with error: \(error)")
				self.databaseChangedPublisher.send(.failure(error))
			}
			self.removedRow = false
		})
		return databaseChangedPublisher.eraseToAnyPublisher()
	}

	func refreshItems() throws {
		var vaults = try dbManager.getAllVaults()
		vaults.sort { $0.listPosition < $1.listPosition }
		startRefreshingVaultLockStates()
		vaultCellViewModels = vaults.map { VaultCellViewModel(vault: $0) }
	}

	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {
		let movedVault = vaultCellViewModels.remove(at: sourceIndex)
		vaultCellViewModels.insert(movedVault, at: destinationIndex)
		try updateVaultListPositions()
		databaseChangedPublisher.send(.success(vaultCellViewModels))
	}

	func removeRow(at index: Int) throws {
		removedRow = true
		let removedVaultCell = vaultCellViewModels.remove(at: index)
		do {
			_ = try vaultManager.removeVault(withUID: removedVaultCell.vault.vaultUID)
		} catch {
			removedRow = false
			throw error
		}
	}

	func lockVault(_ vaultInfo: VaultInfo) async throws {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultInfo.vaultUID)
		let xpc: XPC<VaultLocking> = try await fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		defer {
			fileProviderConnector.invalidateXPC(xpc)
		}
		xpc.proxy.lockVault(domainIdentifier: domainIdentifier)
		vaultInfo.vaultIsUnlocked.value = false
	}

	func refreshVaultLockStates() async {
		await withTaskGroup(of: Void.self) { group in
			for vaultCellViewModel in vaultCellViewModels {
				group.addTask {
					await self.checkVaultUnlockStatus(of: vaultCellViewModel)
				}
			}
		}
	}

	private func startRefreshingVaultLockStates() {
		Task {
			await refreshVaultLockStates()
		}
	}

	private func checkVaultUnlockStatus(of vaultCellViewModel: VaultCellViewModel) async {
		let vault = vaultCellViewModel.vault
		let domainIdentifier = NSFileProviderDomainIdentifier(vault.vaultUID)
		do {
			let xpc: XPC<VaultLocking> = try await fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			let isUnlocked = await xpc.proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier)
			DDLogDebug("Vault \(vault.vaultUID) unlock status: \(isUnlocked ? "Unlocked" : "Locked")")
			vault.vaultIsUnlocked.value = isUnlocked
		} catch {
			DDLogError("Failed to check unlock status for vault \(vault.vaultUID): \(error)")
		}
	}

	private func updateVaultListPositions() throws {
		for i in vaultCellViewModels.indices {
			vaultCellViewModels[i].vault.listPosition = i
		}
		let updatedVaultListPositions = vaultCellViewModels.map { $0.vault.vaultListPosition }
		try dbManager.updateVaultListPositions(updatedVaultListPositions)
	}
}
