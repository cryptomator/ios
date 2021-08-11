//
//  FilesAppUtil.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import UIKit

public enum FilesAppUtil {
	public static func showFilesApp(forVaultUID vaultUID: String) {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			DDLogDebug("containerURL is nil")
			return
		}
		let url = containerURL.appendingPathComponent("File Provider Storage").appendingPathComponent(vaultUID)
		guard let sharedDocumentsURL = FilesAppUtil.changeSchemeToSharedDocuments(for: url) else {
			DDLogDebug("Conversion to \"shareddocuments\" scheme failed")
			return
		}
		UIApplication.shared.open(sharedDocumentsURL)
	}

	private static func changeSchemeToSharedDocuments(for url: URL) -> URL? {
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
		comps?.scheme = "shareddocuments"
		return comps?.url
	}
}
