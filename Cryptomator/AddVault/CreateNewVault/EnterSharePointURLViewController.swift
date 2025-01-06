//
//  EnterSharePointURLViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//

import Combine
import CryptomatorCommonCore
import UIKit

class EnterSharePointURLViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (SharePointURLSetting & Coordinator)?
	private var viewModel: EnterSharePointURLViewModelProtocol
	private var lastReturnButtonPressedSubscriber: AnyCancellable?
	init(viewModel: EnterSharePointURLViewModelProtocol) {
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
		guard let coordinator = coordinator else { return }
		do {
			let url = try viewModel.getValidatedSharePointURL()
			coordinator.setSharePointURL(url)
		} catch {
			print("Error validating SharePoint URL: \(error)")
			coordinator.handleError(error, for: self)
		}
	}

	func lastReturnButtonPressedAction() {
		nextButtonClicked()
	}
}
