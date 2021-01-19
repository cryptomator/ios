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
class ChooseCloudViewController: UITableViewController {
	private static let clouds: [CloudProviderType] = [
		.dropbox,
		.googleDrive,
		.webDAV,
		.localFileSystem
	]
	private let headerTitle: String

	init(headerTitle: String) {
		self.headerTitle = headerTitle
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		tableView.register(CloudCell.self, forCellReuseIdentifier: "ChooseCloudCell")
	}

	// MARK: TableView

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return headerTitle
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		// Prevents the Header Title from being displayed in uppercase
		headerView.textLabel?.text = headerTitle
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return ChooseCloudViewController.clouds.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseCloudCell", for: indexPath) as! CloudCell
		let cloudProviderType = ChooseCloudViewController.clouds[indexPath.row]
		if #available(iOS 14, *) {
			cell.cloudProviderType = cloudProviderType
			cell.setNeedsUpdateConfiguration()
		} else {
			cell.configure(with: cloudProviderType)
		}
		return cell
	}
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI

@available(iOS 13, *)
struct ChooseCloudVCPreview: PreviewProvider {
	static var previews: some View {
		ChooseCloudViewController(headerTitle: "Preview Header Title").toPreview()
	}
}
#endif
