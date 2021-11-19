//
//  CreateNewFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class CreateNewFolderViewController: SingleSectionStaticUITableViewController {
	weak var coordinator: (FolderCreating & Coordinator)?
	private var viewModel: CreateNewFolderViewModelProtocol
	private var lastReturnButtonPressedSubscriber: AnyCancellable?

	init(viewModel: CreateNewFolderViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		let createButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.create"), style: .done, target: self, action: #selector(createButtonClicked))
		navigationItem.leftBarButtonItem = cancelButton
		navigationItem.rightBarButtonItem = createButton
		tableView.rowHeight = 44
		lastReturnButtonPressedSubscriber = viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.createButtonClicked()
		}
	}

	override func configureDataSource() {
		dataSource = BaseDiffableDataSource<SingleSection, TableViewCellViewModel>(viewModel: viewModel, tableView: tableView) { _, _, cellViewModel -> UITableViewCell? in
			let cell = cellViewModel.type.init()
			cell.configure(with: cellViewModel)
			if let textFieldCell = cell as? TextFieldCell {
				let imageConfiguration = UIImage.SymbolConfiguration(font: UIFont.preferredFont(forTextStyle: .title2))
				let folderIcon = UIImage(systemName: "folder", withConfiguration: imageConfiguration)
				let imageView = UIImageView(image: folderIcon)
				imageView.tintColor = UIColor(named: "primary")
				let padding: CGFloat = 5
				let containerView = UIView(frame: CGRect(x: 0, y: 0, width: imageView.frame.width + padding, height: imageView.frame.height))
				containerView.addSubview(imageView)
				textFieldCell.textField.leftView = containerView
				textFieldCell.textField.leftViewMode = .always
				return textFieldCell
			}
			return cell
		}
	}

	@objc func cancel() {
		coordinator?.stop()
	}

	@objc func createButtonClicked() {
		viewModel.createFolder().then { [weak self] folderPath in
			self?.coordinator?.createdNewFolder(at: folderPath)
		}.catch { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import Promises
import SwiftUI

private class CreateNewFolderViewModelMock: SingleSectionTableViewModel, CreateNewFolderViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		PassthroughSubject<Void, Never>().eraseToAnyPublisher()
	}

	override var cells: [TableViewCellViewModel] {
		return [folderNameCellViewModel]
	}

	let folderNameCellViewModel = TextFieldCellViewModel(type: .normal)
	func createFolder() -> Promise<CloudPath> {
		return Promise(CloudPath("/"))
	}

	let headerTitle = "Choose a name for the folder."

	override func getHeaderTitle(for section: Int) -> String? {
		return headerTitle
	}
}

struct CreateNewFolderVCPreview: PreviewProvider {
	static var previews: some View {
		CreateNewFolderViewController(viewModel: CreateNewFolderViewModelMock()).toPreview()
	}
}
#endif
