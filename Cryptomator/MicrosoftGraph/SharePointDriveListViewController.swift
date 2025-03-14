//
//  SharePointDriveListViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit

class SharePointDriveListViewController: SingleSectionTableViewController {
	weak var coordinator: (Coordinator & SharePointAuthenticating)?
	private var viewModel: SharePointDriveListViewModel

	init(viewModel: SharePointDriveListViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("sharePoint.selectDrive.title")
		tableView.register(TableViewCell.self, forCellReuseIdentifier: "SharePointDriveCell")
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.leftBarButtonItem = cancelButton
		// pull to refresh
		initRefreshControl()
		viewModel.startListenForChanges { [weak self] in
			self?.refreshControl?.endRefreshing()
			self?.tableView.reloadData()
		} onError: { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		}
	}

	private func initRefreshControl() {
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
		refreshControl?.beginRefreshing()
		tableView.setContentOffset(CGPoint(x: 0, y: -(refreshControl?.frame.size.height ?? 0)), animated: true)
	}

	@objc func pullToRefresh() {
		viewModel.refreshItems()
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.drives.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SharePointDriveCell", for: indexPath)
		let drive = viewModel.drives[indexPath.row]
		cell.textLabel?.text = drive.name
		cell.imageView?.image = UIImage(systemName: "books.vertical")
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return LocalizedString.getValue("sharePoint.selectDrive.header.title")
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		let itemsLoading = refreshControl?.isRefreshing ?? true
		if !itemsLoading, viewModel.drives.isEmpty {
			return LocalizedString.getValue("sharePoint.selectDrive.emptyList.footer")
		} else {
			return nil
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: section)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let selectedDrive = viewModel.drives[indexPath.row]
		do {
			let credential = SharePointCredential(siteURL: viewModel.siteURL, credential: viewModel.credential, driveID: selectedDrive.identifier)
			try coordinator?.authenticated(credential)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}
