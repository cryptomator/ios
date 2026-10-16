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
	let siteURL: URL

	private let discovery: MicrosoftGraphDiscovery
	private var changeListener: (() -> Void)?
	private var driveListener: ((MicrosoftGraphDrive) -> Void)?
	private var errorListener: ((Error) -> Void)?
	private(set) var drives: [MicrosoftGraphDrive] = []

	init(credential: MicrosoftGraphCredential, siteURL: URL) {
		self.credential = credential
		self.discovery = MicrosoftGraphDiscovery(credential: credential)
		self.siteURL = siteURL
	}

	func startListenForChanges(onChange: @escaping () -> Void, onDriveDetection: @escaping (MicrosoftGraphDrive) -> Void, onError: @escaping (Error) -> Void) {
		changeListener = onChange
		driveListener = onDriveDetection
		errorListener = onError
		refreshItems()
	}

	func refreshItems() {
		Task {
			do {
				let site = try await discovery.fetchSharePointSite(for: siteURL)
				try await fetchDrives(for: site.identifier)
			} catch {
				errorListener?(error)
			}
		}
	}

	private func fetchDrives(for siteIdentifier: String) async throws {
		let drives = try await discovery.fetchSharePointDrives(for: siteIdentifier)
		self.drives = drives
		if drives.count == 1, let drive = drives.first {
			driveListener?(drive)
		} else {
			changeListener?()
		}
	}
}
