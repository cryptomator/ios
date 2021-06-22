//
//  CreateNewFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class CreateNewFolderViewController: SingleSectionHeaderTableViewController {
	weak var coordinator: (FolderCreating & Coordinator)?
	private var viewModel: CreateNewFolderViewModelProtocol
	private lazy var nameCell: TextFieldCell = {
		let cell = TextFieldCell()
		cell.textField.placeholder = NSLocalizedString("createNewFolder.cells.name", comment: "")
		cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
		cell.textField.becomeFirstResponder()
		let folderIcon = UIImage(named: "folder")
		let imageView = UIImageView(image: folderIcon)
		let padding: CGFloat = 5
		let containerView = UIView(frame: CGRect(x: 0, y: 0, width: imageView.frame.width + padding, height: imageView.frame.height))
		containerView.addSubview(imageView)
		cell.textField.leftView = containerView
		cell.textField.leftViewMode = .always
		return cell
	}()

	init(viewModel: CreateNewFolderViewModelProtocol) {
		self.viewModel = viewModel
		super.init(with: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		let createButton = UIBarButtonItem(title: NSLocalizedString("common.button.create", comment: ""), style: .done, target: self, action: #selector(createButtonClicked))
		navigationItem.leftBarButtonItem = cancelButton
		navigationItem.rightBarButtonItem = createButton
		tableView.rowHeight = 44
	}

	@objc func cancel() {
		coordinator?.stop()
	}

	@objc func createButtonClicked() {
		viewModel.createFolder().then { [weak self] folderPath in
			self?.coordinator?.createdNewFolder(at: folderPath)
		}.catch { [weak self] error in
			guard let self = self else {
				return
			}
			self.coordinator?.handleError(error, for: self)
		}
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
		viewModel.folderName = textField.text
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return nameCell
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import Promises
import SwiftUI
private class CreateNewFolderViewModelMock: CreateNewFolderViewModelProtocol {
	var folderName: String?

	func createFolder() -> Promise<CloudPath> {
		return Promise(CloudPath("/"))
	}

	let headerTitle = "Choose a name for the folder."

	let headerUppercased = false
}

struct CreateNewFolderVCPreview: PreviewProvider {
	static var previews: some View {
		CreateNewFolderViewController(viewModel: CreateNewFolderViewModelMock()).toPreview()
	}
}
#endif
