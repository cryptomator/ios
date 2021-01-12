//
//  VaultListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import Foundation
class VaultListViewModel: VaultListViewModelProtocol {
	var vaults = [VaultInfo]()
	private let dbManager: DatabaseManager
	private let vaultAccountManager: VaultAccountManager

	convenience init() {
		self.init(dbManager: DatabaseManager.shared, vaultAccountManager: VaultAccountManager.shared)
	}

	init(dbManager: DatabaseManager, vaultAccountManager: VaultAccountManager) {
		self.dbManager = dbManager
		self.vaultAccountManager = vaultAccountManager
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
		try vaultAccountManager.removeAccount(with: removedVault.vaultUID)
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
