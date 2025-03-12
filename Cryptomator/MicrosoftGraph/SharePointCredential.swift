//
//  SharePointCredential.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public struct SharePointCredential {
	public let siteURL: URL
	public let credential: MicrosoftGraphCredential
	public let driveID: String
}
