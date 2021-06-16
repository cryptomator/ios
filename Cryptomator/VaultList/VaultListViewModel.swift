//
//  VaultListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import GRDB
class VaultListViewModel: VaultListViewModelProtocol {
	var vaults = [VaultInfo]()

	private let dbManager: DatabaseManager
	private let vaultManager: VaultManager
	private var observation: TransactionObserver?

	convenience init() {
		self.init(dbManager: DatabaseManager.shared, vaultManager: VaultManager.shared)
	}

	init(dbManager: DatabaseManager, vaultManager: VaultManager) {
		self.dbManager = dbManager
		self.vaultManager = vaultManager
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void) {
		observation = dbManager.observeVaultAccounts(onError: onError, onChange: { _ in
			do {
				try self.refreshItems()
				onChange()
			} catch {
				onError(error)
			}
		})
	}

	func refreshItems() throws {
		vaults = try dbManager.getAllVaults()
		vaults.sort { $0.listPosition < $1.listPosition }
	}

	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {
		let movedVault = vaults.remove(at: sourceIndex)
		vaults.insert(movedVault, at: destinationIndex)
		try updateVaultListPositions()
	}

	func removeRow(at index: Int) throws {
		let removedVault = vaults.remove(at: index)
		try vaultManager.removeVault(withUID: removedVault.vaultUID).catch { error in
			DDLogError("VaultListViewModel: remove row failed with error: \(error)")
		}
		try updateVaultListPositions()
	}

	private func updateVaultListPositions() throws {
		for i in vaults.indices {
			vaults[i].listPosition = i
		}
		let updatedVaultListPositions = vaults.map { $0.vaultListPosition }
		try dbManager.updateVaultListPositions(updatedVaultListPositions)
	}
}
