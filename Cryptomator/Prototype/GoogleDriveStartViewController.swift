//
//  GoogleDriveStartViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit
class GoogleDriveStartViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		let accountUIDs: [String]
		do {
			accountUIDs = try CloudProviderAccountManager.shared.getAllAccountUIDs(for: .googleDrive)
		} catch {
			print("error: \(error)")
			return
		}
		if let firstAccountUID = accountUIDs.first {
			let credential = GoogleDriveCredential(with: firstAccountUID)
			let accountOverviewVC = GoogleDriveAccountOverviewViewController(for: credential)
			navigationController?.pushViewController(accountOverviewVC, animated: true)
		} else {
			let loginVC = GoogleDriveLoginViewController()
			navigationController?.pushViewController(loginVC, animated: true)
		}
	}
}
