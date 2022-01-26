//
//  ChooseCloudViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class ChooseCloudViewController: BaseUITableViewController {
	weak var coordinator: CloudChoosing?

	private let viewModel: ChooseCloudViewModel

	init(viewModel: ChooseCloudViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.register(CloudCell.self, forCellReuseIdentifier: "ChooseCloudCell")
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.clouds.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseCloudCell", for: indexPath) as! CloudCell
		let cloudProviderType = viewModel.clouds[indexPath.row]
		if #available(iOS 14, *) {
			cell.cloudProviderType = cloudProviderType
			cell.setNeedsUpdateConfiguration()
		} else {
			cell.configure(with: cloudProviderType)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel.headerTitle
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cloudProviderType = viewModel.clouds[indexPath.row]
		coordinator?.showAccountList(for: cloudProviderType)
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.headerTitle
	}
}

#if DEBUG
import SwiftUI

struct ChooseCloudVCPreview: PreviewProvider {
	static var previews: some View {
		ChooseCloudViewController(viewModel: ChooseCloudViewModel(clouds: [.dropbox, .googleDrive, .webDAV(type: .custom), .localFileSystem(type: .iCloudDrive)], headerTitle: "Preview Header Title")).toPreview()
	}
}
#endif
