//
//  CreateNewLocalVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 24.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class CreateNewLocalVaultViewController: CreateNewVaultChooseFolderViewController {
	override func onItemsChange() {
		guard let viewModel = viewModel as? CreateNewVaultChooseFolderViewModelProtocol else {
			return
		}
		do {
			coordinator?.chooseItem(try viewModel.chooseCurrentFolder())
		} catch {
			coordinator?.handleError(error: error)
		}
	}
}
