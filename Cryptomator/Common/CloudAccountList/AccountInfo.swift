//
//  AccountInfo.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import GRDB

public struct AccountInfo: Decodable, FetchableRecord {
	let cloudProviderAccount: CloudProviderAccount
	private(set) var accountListPosition: AccountListPosition

	init(cloudProviderAccount: CloudProviderAccount, accountListPosition: AccountListPosition) {
		self.cloudProviderAccount = cloudProviderAccount
		self.accountListPosition = accountListPosition
	}

	var cloudProviderType: CloudProviderType {
		return cloudProviderAccount.cloudProviderType
	}

	var accountUID: String {
		return cloudProviderAccount.accountUID
	}

	var listPosition: Int {
		get {
			accountListPosition.position!
		}
		set {
			accountListPosition.position = newValue
		}
	}
}
