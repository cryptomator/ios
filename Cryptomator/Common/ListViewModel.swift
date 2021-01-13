//
//  ListViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 08.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
protocol ListViewModel {
	func refreshItems() throws
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws
	func removeRow(at index: Int) throws
}

protocol VaultListViewModelProtocol: ListViewModel {
	var vaults: [VaultInfo] { get }
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void)
}
