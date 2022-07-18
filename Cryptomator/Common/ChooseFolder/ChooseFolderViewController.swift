//
//  ChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class ChooseFolderViewController: SingleSectionTableViewController {
	let viewModel: ChooseFolderViewModelProtocol
	weak var coordinator: (Coordinator & FolderChoosing)?

	private lazy var header: HeaderWithSearchbar = .init(title: viewModel.headerTitle, searchBar: searchController.searchBar)
	private lazy var searchController: UISearchController = .init()

	init(with viewModel: ChooseFolderViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		cancelButton.tintColor = .cryptomatorPrimary
		var toolbarItems = [cancelButton]
		if viewModel.canCreateFolder {
			let flexibleSpaceItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
			let createFolderButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.createFolder"), style: .plain, target: self, action: #selector(createNewFolder))
			createFolderButton.tintColor = .cryptomatorPrimary
			toolbarItems.append(flexibleSpaceItem)
			toolbarItems.append(createFolderButton)
		}
		setToolbarItems(toolbarItems, animated: false)

		tableView.register(FolderCell.self, forCellReuseIdentifier: "FolderCell")
		tableView.register(FileCell.self, forCellReuseIdentifier: "FileCell")

		// pull to refresh
		initRefreshControl()
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			self?.onItemsChange()
		} onVaultDetection: { [weak self] vault in
			guard let self = self else { return }
			self.tableView.reloadData()
			self.showDetectedVault(vault)
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let isToolbarHidden = navigationController?.isToolbarHidden, isToolbarHidden, !viewModel.foundMasterkey {
			navigationController?.setToolbarHidden(false, animated: animated)
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if !(navigationController?.topViewController is ChooseFolderViewController) {
			navigationController?.setToolbarHidden(true, animated: animated)
		}
	}

	func showDetectedVault(_ vault: VaultDetailItem) {
		fatalError("not implemented")
	}

	func onItemsChange() {
		refreshControl?.endRefreshing()
		tableView.reloadData()
	}

	@objc func cancel() {
		coordinator?.close()
	}

	@objc func createNewFolder() {
		coordinator?.showCreateNewFolder(parentPath: viewModel.cloudPath)
	}

	@objc func pullToRefresh() {
		viewModel.refreshItems()
	}

	private func initRefreshControl() {
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
		refreshControl?.beginRefreshing()
		tableView.setContentOffset(CGPoint(x: 0, y: -(refreshControl?.frame.size.height ?? 0)), animated: true)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.items.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: CloudItemCell
		let item = viewModel.items[indexPath.row]
		switch item.itemType {
		case .folder:
			// swiftlint:disable:next force_cast
			cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! FolderCell
		default:
			// swiftlint:disable:next force_cast
			cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath) as! FileCell
		}

		if #available(iOS 14, *) {
			cell.item = item
			cell.setNeedsUpdateConfiguration()
		} else {
			cell.configure(with: item)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		let itemsLoading = refreshControl?.isRefreshing ?? true
		if !itemsLoading, viewModel.items.isEmpty {
			return LocalizedString.getValue("chooseFolder.emptyFolder.footer")
		} else {
			return nil
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if viewModel.foundMasterkey {
			return nil
		}
		let header = UITableViewHeaderFooterView()
		header.textLabel?.text = viewModel.headerTitle
		return header
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = viewModel.items[indexPath.row]
		coordinator?.showItems(for: item.cloudPath)
	}
}

private class HeaderWithSearchbar: UITableViewHeaderFooterView {
	lazy var title: UILabel = .init()

	convenience init(title: String, searchBar: UISearchBar) {
		self.init(reuseIdentifier: nil)
		self.title.text = title

		self.title.font = UIFont.preferredFont(forTextStyle: .footnote)
		self.title.textColor = .secondaryLabel
		searchBar.sizeToFit()
		searchBar.backgroundColor = .clear
		searchBar.backgroundImage = UIImage()

		searchBar.translatesAutoresizingMaskIntoConstraints = false
		self.title.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(searchBar)
		contentView.addSubview(self.title)

		NSLayoutConstraint.activate([
			searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			searchBar.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),

			self.title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			self.title.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			self.title.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
			self.title.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}
}

#if DEBUG
import SwiftUI

private class ChooseFolderViewModelMock: ChooseFolderViewModelProtocol {
	var headerTitle: String {
		cloudPath.path
	}

	let foundMasterkey = false
	let canCreateFolder: Bool
	let cloudPath: CloudPath
	let items = [
		CloudItemMetadata(name: "Bar", cloudPath: CloudPath("/Bar"), itemType: .file, lastModifiedDate: Date(), size: 42),
		CloudItemMetadata(name: "Foo", cloudPath: CloudPath("/Foo"), itemType: .folder, lastModifiedDate: nil, size: nil)
	]

	init(cloudPath: CloudPath, canCreateFolder: Bool) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onVaultDetection: @escaping (VaultDetailItem) -> Void) {
		onChange()
	}

	func refreshItems() {}
}

struct ChooseFolderVCPreview: PreviewProvider {
	static var previews: some View {
		ChooseFolderViewController(with: ChooseFolderViewModelMock(cloudPath: CloudPath("/Preview/Folder"), canCreateFolder: true)).toPreview()
	}
}
#endif
