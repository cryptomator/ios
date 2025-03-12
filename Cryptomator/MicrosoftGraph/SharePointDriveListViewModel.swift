//
//  SharePointDriveListViewModel.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

class SharePointDriveListViewModel {
	let credential: MicrosoftGraphCredential
	let url: URL

	private let discovery: MicrosoftGraphDiscovery
	private var changeListener: (() -> Void)?
	private var errorListener: ((Error) -> Void)?
	private(set) var drives: [MicrosoftGraphDrive] = []

	init(credential: MicrosoftGraphCredential, url: URL) {
		self.credential = credential
		self.discovery = MicrosoftGraphDiscovery(credential: credential)
		self.url = url
	}

	func startListenForChanges(onChange: @escaping () -> Void, onError: @escaping (Error) -> Void) {
		changeListener = onChange
		errorListener = onError
		refreshItems()
	}

	func refreshItems() {
		guard let hostName = url.host else {
			errorListener?(SharePointURLValidatorError.invalidURL)
			return
		}
		discovery.fetchSharePointSite(for: hostName, serverRelativePath: url.lastPathComponent).then { site in
			self.fetchDrives(for: site.identifier)
		}.catch { error in
			self.errorListener?(error)
		}
	}

	private func fetchDrives(for siteIdentifier: String) {
		discovery.fetchSharePointDrives(for: siteIdentifier).then { drives in
			self.drives = drives
			self.changeListener?()
		}.catch { error in
			self.errorListener?(error)
		}
	}
}
