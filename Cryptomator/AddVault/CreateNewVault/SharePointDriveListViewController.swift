//
//  SharePointDriveListViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit

class SharePointDriveListViewController: BaseUITableViewController {
	private var viewModel: SharePointDriveListViewModel

	init(viewModel: SharePointDriveListViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.register(CloudCell.self, forCellReuseIdentifier: "SharePointDriveCell")
		viewModel.reloadData = { [weak self] in
			self?.tableView.reloadData()
		}

		title = LocalizedString.getValue("addVault.selectDrive.navigation.title")
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.drives.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "SharePointDriveCell", for: indexPath) as? CloudCell else {
			fatalError("Could not dequeue CloudCell")
		}

		let drive = viewModel.drives[indexPath.row]
		configure(cell, with: drive)

		return cell
	}

	// MARK: - Styling Configuration

	private func configure(_ cell: CloudCell, with drive: MicrosoftGraphDrive) {
		cell.textLabel?.text = drive.name
		cell.imageView?.image = UIImage(systemName: "folder")
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let selectedDrive = viewModel.drives[indexPath.row]
		viewModel.selectDrive(selectedDrive)
		tableView.deselectRow(at: indexPath, animated: true)
	}
}
