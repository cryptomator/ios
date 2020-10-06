//
//  DropboxLoginViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 01.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import Promises
import UIKit
class DropboxLoginViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()

		let button = UIButton(frame: CGRect(x: 50, y: 100, width: 300, height: 50))
		button.setTitle("New Login", for: .normal)
		button.backgroundColor = .blue
		button.addTarget(self, action: #selector(login), for: .touchUpInside)

		let existingButton = UIButton(frame: CGRect(x: 50, y: 200, width: 300, height: 50))
		existingButton.setTitle("Existing Login", for: .normal)
		existingButton.backgroundColor = .green
		existingButton.addTarget(self, action: #selector(loginExisting), for: .touchUpInside)
		view.addSubview(button)
		view.addSubview(existingButton)
	}

	@objc func login() {
		let authenticator = DropboxCloudAuthenticator()

		let rootCloudPath = CloudPath("/")
		authenticator.authenticate(from: self).then { credential -> CloudProvider in
			print("authenticated with tokenUid: \(credential.tokenUid)")
			return DropboxCloudProvider(with: credential)
		}.then { provider in
			provider.fetchItemList(forFolderAt: rootCloudPath, withPageToken: nil)
		}.then { cloudItemList in
			for item in cloudItemList.items {
				print(item.name)
			}
		}
	}

	@objc func loginExisting() {
		let credential = DropboxCredential(tokenUid: "307956887")
		let provider = DropboxCloudProvider(with: credential)
		let rootCloudPath = CloudPath("/")
		provider.fetchItemList(forFolderAt: rootCloudPath, withPageToken: nil).then { cloudItemList -> Promise<CloudItemList> in
			for item in cloudItemList.items {
				print(item.name)
			}
			print("2nd Account:")
			let credential2nd = DropboxCredential(tokenUid: "3265399968")
			let provider2nd = DropboxCloudProvider(with: credential2nd)
			return provider2nd.fetchItemList(forFolderAt: rootCloudPath, withPageToken: nil)
		}.then { cloudItemList in
			for item in cloudItemList.items {
				print(item.name)
			}
		}.catch { error in
			print("Provider Error: \(error)")
		}
	}
}
