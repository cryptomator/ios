//
//  ChooseFolderViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class ChooseFolderViewController: SingleSectionTableViewController {
	let viewModel: ChooseFolderViewModelProtocol
	weak var coordinator: (Coordinator & FolderChoosing)?
	private lazy var header: HeaderWithSearchbar = {
		return HeaderWithSearchbar(title: viewModel.headerTitle, searchBar: searchController.searchBar)
	}()

	private lazy var searchController: UISearchController = {
		let searchController = UISearchController(searchResultsController: self)
		return searchController
	}()

	init(with viewModel: ChooseFolderViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
	}

	override func loadView() {
		super.loadView()
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		cancelButton.tintColor = UIColor(named: "primary")
		let toolbarItems = [cancelButton]
		setToolbarItems(toolbarItems, animated: false)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		navigationController?.setToolbarHidden(false, animated: true)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.register(FolderCell.self, forCellReuseIdentifier: "FolderCell")
		tableView.register(FileCell.self, forCellReuseIdentifier: "FileCell")
		// pull to refresh
		initRefreshControl()
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			guard let self = self else { return }
			self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
		} onMasterkeyDetection: { [weak self] masterkeyPath in
			guard let self = self else { return }
			self.tableView.reloadData()
			self.showDetectedMasterkey(at: masterkeyPath)
		}
	}

	func showDetectedMasterkey(at path: CloudPath) {
		fatalError("not implemented")
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

	// MARK: TableView

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if viewModel.foundMasterkey {
			return nil
		}
		return header
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.items.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: CloudItemCell
		let item = viewModel.items[indexPath.row]
		switch item.itemType {
		case .folder:
			cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! FolderCell
		default:
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

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = viewModel.items[indexPath.row]
		coordinator?.showItems(for: item.cloudPath)
	}
}

private class HeaderWithSearchbar: UITableViewHeaderFooterView {
	lazy var title: UILabel = {
		return UILabel()
	}()

	convenience init(title: String, searchBar: UISearchBar) {
		self.init(reuseIdentifier: nil)
		self.title.text = title

		self.title.font = UIFont.preferredFont(forTextStyle: .footnote)
		if #available(iOS 13, *) {
			self.title.textColor = .secondaryLabel
		} else {
			self.title.textColor = UIColor(named: "secondaryLabel")
		}
		searchBar.sizeToFit()
		searchBar.backgroundColor = .clear
		searchBar.backgroundImage = UIImage()

		searchBar.translatesAutoresizingMaskIntoConstraints = false
		self.title.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(searchBar)
		contentView.addSubview(self.title)

		NSLayoutConstraint.activate([
			searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			searchBar.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

			self.title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			self.title.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
			self.title.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
			self.title.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
		])
	}
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI
private class ChooseFolderViewModelMock: ChooseFolderViewModelProtocol {
	let foundMasterkey = false
	let canCreateFolder: Bool
	let cloudPath: CloudPath
	let items = [CloudItemMetadata(name: "Bar",
	                               cloudPath: CloudPath("/Bar"),
	                               itemType: .file,
	                               lastModifiedDate: Date(),
	                               size: 42),
	             CloudItemMetadata(name: "Foo",
	                               cloudPath: CloudPath("/Foo"),
	                               itemType: .folder,
	                               lastModifiedDate: nil,
	                               size: nil)]

	init(cloudPath: CloudPath, canCreateFolder: Bool) {
		self.canCreateFolder = canCreateFolder
		self.cloudPath = cloudPath
	}

	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void, onMasterkeyDetection: @escaping (CloudPath) -> Void) {
		onChange()
	}

	func refreshItems() {}
}

@available(iOS 13, *)
struct ChooseFolderVCPreview: PreviewProvider {
	static var previews: some View {
		ChooseFolderViewController(with: ChooseFolderViewModelMock(cloudPath: CloudPath("/Preview/Folder"),
		                                                           canCreateFolder: true)).toPreview()
	}
}
#endif
