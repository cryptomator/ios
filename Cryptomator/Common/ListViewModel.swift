//
//  ListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
protocol ListViewModel {
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws
	func removeRow(at index: Int) throws
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void)
}

protocol VaultListViewModelProtocol: ListViewModel {
	var vaults: [VaultInfo] { get }
}

protocol AccountListViewModelProtocol: ListViewModel {
	var accounts: [AccountCellContent] { get }
	var title: String { get }
}
