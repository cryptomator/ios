//
//  TrustedHubHostsViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class TrustedHubHostsViewController: BaseUITableViewController {
	private enum Section {
		case hosts
		case clearAll
	}

	private enum Item: Hashable {
		case host(String)
		case clearAll
	}

	private let viewModel: TrustedHubHostsViewModel
	private var dataSource: UITableViewDiffableDataSource<Section, Item>?
	private lazy var emptyListMessage: UIView = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textAlignment = .center
		label.numberOfLines = 0
		label.text = viewModel.emptyListMessage
		label.translatesAutoresizingMaskIntoConstraints = false

		let container = UIView()
		container.addSubview(label)
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: container.readableContentGuide.leadingAnchor),
			label.trailingAnchor.constraint(equalTo: container.readableContentGuide.trailingAnchor),
			label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
		])
		return container
	}()

	init(viewModel: TrustedHubHostsViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HostCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ClearAllCell")
		configureDataSource()
		applySnapshot()
	}

	private func configureDataSource() {
		dataSource = UITableViewDiffableDataSource<Section, Item>(tableView: tableView) { tableView, indexPath, item in
			switch item {
			case let .host(host):
				let cell = tableView.dequeueReusableCell(withIdentifier: "HostCell", for: indexPath)
				cell.textLabel?.text = host
				cell.selectionStyle = .none
				return cell
			case .clearAll:
				let cell = tableView.dequeueReusableCell(withIdentifier: "ClearAllCell", for: indexPath)
				cell.textLabel?.text = LocalizedString.getValue("trustedHubHosts.clearAll")
				cell.textLabel?.textColor = .systemRed
				cell.selectionStyle = .default
				return cell
			}
		}
	}

	private func applySnapshot() {
		var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
		let hosts = viewModel.hosts
		if hosts.isEmpty {
			tableView.backgroundView = emptyListMessage
			tableView.contentInsetAdjustmentBehavior = .never
			tableView.separatorStyle = .none
		} else {
			tableView.backgroundView = nil
			tableView.contentInsetAdjustmentBehavior = .automatic
			tableView.separatorStyle = .singleLine
			snapshot.appendSections([.hosts, .clearAll])
			snapshot.appendItems(hosts.map { .host($0) }, toSection: .hosts)
			snapshot.appendItems([.clearAll], toSection: .clearAll)
		}
		dataSource?.apply(snapshot, animatingDifferences: false)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let item = dataSource?.itemIdentifier(for: indexPath) else { return }
		switch item {
		case .host:
			break
		case .clearAll:
			showClearAllAlert()
		}
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let item = dataSource?.itemIdentifier(for: indexPath), case let .host(host) = item else {
			return nil
		}
		let deleteAction = UIContextualAction(style: .destructive, title: LocalizedString.getValue("common.button.remove")) { [weak self] _, _, completion in
			self?.viewModel.removeHost(host)
			self?.applySnapshot()
			completion(true)
		}
		return UISwipeActionsConfiguration(actions: [deleteAction])
	}

	// MARK: - Private

	private func showClearAllAlert() {
		let alertController = UIAlertController(title: nil, message: LocalizedString.getValue("trustedHubHosts.clearAll.alert.message"), preferredStyle: .alert)
		let clearAction = UIAlertAction(title: LocalizedString.getValue("common.button.clear"), style: .destructive) { [weak self] _ in
			self?.viewModel.clearAllHosts()
			self?.applySnapshot()
		}
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel)
		alertController.addAction(clearAction)
		alertController.addAction(cancelAction)
		present(alertController, animated: true, completion: nil)
	}
}
