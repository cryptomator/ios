//
//  SharePointDriveListViewModel.swift
//  Cryptomator
//
//  Created by Majid Achhoud
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

class SharePointDriveListViewModel: SingleSectionTableViewModel {
	private let discovery: MicrosoftGraphDiscovery
	private let sharePointURL: String
	private let account: AccountInfo

	var drives: [MicrosoftGraphDrive] = [] {
		didSet {
			reloadData?()
		}
	}

	var reloadData: (() -> Void)?
	var didSelectDrive: ((MicrosoftGraphDrive) -> Void)?

	init(discovery: MicrosoftGraphDiscovery, sharePointURL: String, account: AccountInfo) {
		self.discovery = discovery
		self.sharePointURL = sharePointURL
		self.account = account
		super.init()
		fetchSiteAndDrives()
	}

	func selectDrive(_ drive: MicrosoftGraphDrive) {
		didSelectDrive?(drive)
	}

	private func fetchSiteAndDrives() {
		guard let urlComponents = URL(string: sharePointURL),
		      let hostName = urlComponents.host else {
			print("Invalid SharePoint URL")
			return
		}

		var serverRelativePath = urlComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		if serverRelativePath.hasPrefix("sites/") {
			serverRelativePath = String(serverRelativePath.dropFirst("sites/".count))
		}

		discovery.fetchSharePointSite(for: hostName, serverRelativePath: serverRelativePath)
			.then { site in
				self.fetchDrives(for: site.identifier)
			}.catch { error in
				print("Failed to fetch SharePoint site: \(error)")
			}
	}

	private func fetchDrives(for siteIdentifier: String) {
		discovery.fetchSharePointDocumentLibraries(for: siteIdentifier).then { drives in
			self.drives = drives
		}.catch { error in
			print("Failed to fetch drives: \(error)")
		}
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else { return nil }
		return LocalizedString.getValue("addVault.selectDrive.navigation.title")
	}

	override var title: String? {
		return LocalizedString.getValue("addVault.selectDrive.header.description")
	}
}
