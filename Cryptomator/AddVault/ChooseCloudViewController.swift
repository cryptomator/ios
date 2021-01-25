//
//  ChooseCloudViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import Foundation
import UIKit
class ChooseCloudViewController: SingleSectionTableViewController {
	let viewModel: ChooseCloudViewModel
	weak var coordinator: CloudChoosing?

	init(viewModel: ChooseCloudViewModel) {
		self.viewModel = viewModel
		super.init(with: viewModel)
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		tableView.register(CloudCell.self, forCellReuseIdentifier: "ChooseCloudCell")
	}

	// MARK: TableView

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.clouds.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cloudProviderType = viewModel.clouds[indexPath.row]
		coordinator?.showAccountList(for: cloudProviderType)
	}
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI

@available(iOS 13, *)
struct ChooseCloudVCPreview: PreviewProvider {
	static var previews: some View {
		ChooseCloudViewController(viewModel: ChooseCloudViewModel(clouds: [.dropbox,
		                                                                   .googleDrive,
		                                                                   .webDAV,
		                                                                   .localFileSystem],
		                                                          headerTitle: "Preview Header Title")).toPreview()
	}
}
#endif
