//
//  SetVaultNameViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class SetVaultNameViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (VaultNaming & Coordinator)?
	private var viewModel: SetVaultNameViewModelProtocol

	init(viewModel: SetVaultNameViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.next"), style: .done, target: self, action: #selector(nextButtonClicked))
		navigationItem.rightBarButtonItem = doneButton
		tableView.rowHeight = 44
	}

	@objc func nextButtonClicked() {
		do {
			coordinator?.setVaultName(try viewModel.getValidatedVaultName())
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import SwiftUI

struct SetVaultNameVCPreview: PreviewProvider {
	static var previews: some View {
		SetVaultNameViewController(viewModel: SetVaultNameViewModel()).toPreview()
	}
}
#endif
