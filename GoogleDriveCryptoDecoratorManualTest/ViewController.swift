//
//  ViewController.swift
//  GoogleDriveCryptoDecoratorManualTest
//
//  Created by Philipp Schmid on 13.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import CryptomatorCryptoLib
import Promises
import UIKit
class ViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		let authentication = GoogleDriveCloudAuthentication()
		let provider = GoogleDriveCloudProvider(with: authentication)
		let masterKeyRemoteURL = URL(fileURLWithPath: "/Test/TestCryptomatorTresor/masterkey.cryptomator", isDirectory: false)
		let documentsURL = getDocumentsDirectory()
		let masterKeyLocalURL = documentsURL.appendingPathComponent("masterkey.cryptomator")
		authentication.authenticate(from: self).then {
			provider.downloadFile(from: masterKeyRemoteURL, to: masterKeyLocalURL)
		}.then { _ -> Promise<CloudItemList> in
			print("masterKey: \(masterKeyLocalURL.path)")
			let masterKey = try Masterkey.createFromMasterkeyFile(file: masterKeyLocalURL, password: "testtest")
			let cryptor = Cryptor(masterKey: masterKey)
			print("cryptor initialized")
			let remotePathToVault = URL(fileURLWithPath: "/Test/TestCryptomatorTresor/", isDirectory: true)
			let decorator = try VaultFormat7ProviderDecorator(delegate: provider, remotePathToVault: remotePathToVault, cryptor: cryptor)
			let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
			return decorator.fetchItemList(forFolderAt: rootURL, withPageToken: nil)
		}.then { fileList in
			print("fileList received")
			for item in fileList.items {
				print(item.name)
			}
		}.catch { error in
			print("Error: \(error)")
		}
	}

	func getDocumentsDirectory() -> URL {
		let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		return paths[0]
	}
}
