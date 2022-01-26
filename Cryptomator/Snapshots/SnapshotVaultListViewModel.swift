//
//  SnapshotVaultListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 13.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if SNAPSHOTS
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
			CloudPath(LocalizedString.getValue("snapshots.main.vault1")),
			CloudPath(LocalizedString.getValue("snapshots.main.vault2")),
			CloudPath(LocalizedString.getValue("snapshots.main.vault3")),
			CloudPath(LocalizedString.getValue("snapshots.main.vault4"))
		]
		let vaults = cloudProviderAccounts.enumerated().map { index, cloudProviderAccount -> VaultInfo in
			let vaultAccount = VaultAccount(vaultUID: UUID().uuidString, delegateAccountUID: cloudProviderAccount.accountUID, vaultPath: vaultPaths[index], vaultName: vaultPaths[index].lastPathComponent)
			let vaultListPosition = VaultListPosition(id: nil, position: index, vaultUID: vaultAccount.vaultUID)
			let vaultInfo = VaultInfo(vaultAccount: vaultAccount, cloudProviderAccount: cloudProviderAccount, vaultListPosition: vaultListPosition)
			if index == 0 {
				vaultInfo.vaultIsUnlocked.value = true
			}
			return vaultInfo
		}
		return vaults.map { VaultCellViewModel(vault: $0) }
	}
}
#endif
