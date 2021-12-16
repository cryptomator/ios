//
//  SnapshotVaultListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 13.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

class SnapshotVaultListViewModel: VaultListViewModelProtocol {
	@Published var showMockVaults = false
	func refreshVaultLockStates() -> Promise<Void> {
		return Promise(())
	}

	let headerTitle = LocalizedString.getValue("vaultList.header.title")
	let emptyListMessage = LocalizedString.getValue("vaultList.emptyList.message")

	var removeAlert: ListViewModelAlertContent {
		.init(title: "", message: "", confirmButtonText: "")
	}

	private lazy var vaultCellViewModels: [VaultCellViewModel] = createVaulCells()

	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {}

	func removeRow(at index: Int) throws {}

	func startListenForChanges() -> AnyPublisher<Result<[TableViewCellViewModel], Error>, Never> {
		return $showMockVaults.map { showMockVaults in
			let result: Result<[TableViewCellViewModel], Error>
			if showMockVaults {
				result = .success(self.vaultCellViewModels)
			} else {
				result = .success([])
			}
			return result
		}.eraseToAnyPublisher()
	}

	private func createVaulCells() -> [VaultCellViewModel] {
		let cloudProviderAccounts = [
			CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .oneDrive),
			CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .googleDrive),
			CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .dropbox),
			CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .localFileSystem(type: .iCloudDrive))
		]
		let vaultPaths = [
			CloudPath("/Work"),
			CloudPath("/Family"),
			CloudPath("/Documents"),
			CloudPath("/Trip to California")
		]
		let vaults = cloudProviderAccounts.enumerated().map { index, cloudProviderAccount -> VaultInfo in
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: vaultPaths[index], vaultName: vaultPaths[index].lastPathComponent)
			let vaultListPosition = VaultListPosition(id: nil, position: index, vaultUID: vaultAccount.vaultUID)
			return VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
		}
		return vaults.map { VaultCellViewModel(vault: $0) }
	}
}
