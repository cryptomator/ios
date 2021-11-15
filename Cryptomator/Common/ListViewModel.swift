//
//  ListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation
import Promises

protocol ListViewModel {
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws
	func removeRow(at index: Int) throws
}

protocol VaultListViewModelProtocol: ListViewModel {
	func refreshVaultLockStates() -> Promise<Void>
	func startListenForChanges() -> AnyPublisher<Result<[VaultCellViewModel], Error>, Never>
}

protocol AccountListViewModelProtocol: ListViewModel {
	var accounts: [AccountCellContent] { get }
	var accountInfos: [AccountInfo] { get }
	var title: String { get }
	var cloudProviderType: CloudProviderType { get }
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void)
}
