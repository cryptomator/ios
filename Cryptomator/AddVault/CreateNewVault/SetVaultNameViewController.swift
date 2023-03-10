//
//  SetVaultNameViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class SetVaultNameViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (VaultNaming & Coordinator)?
	private var viewModel: SetVaultNameViewModelProtocol
	private var lastReturnButtonPressedSubscriber: AnyCancellable?

	init(viewModel: SetVaultNameViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.next"), style: .done, target: self, action: #selector(nextButtonClicked))
		navigationItem.rightBarButtonItem = doneButton
		lastReturnButtonPressedSubscriber = viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.lastReturnButtonPressedAction()
		}
	}

	@objc func nextButtonClicked() {
		do {
			try coordinator?.setVaultName(viewModel.getValidatedVaultName())
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	func lastReturnButtonPressedAction() {
		nextButtonClicked()
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
