//
//  VaultInfo.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import GRDB

public class VaultInfo: Decodable, FetchableRecord {
	var vaultAccount: VaultAccount
	let cloudProviderAccount: CloudProviderAccount
	private(set) var vaultListPosition: VaultListPosition
	let vaultIsUnlocked = Bindable(false)

	enum CodingKeys: String, CodingKey {
		case vaultAccount
		case cloudProviderAccount
		case vaultListPosition
	}

	init(vaultAccount: VaultAccount, cloudProviderAccount: CloudProviderAccount, vaultListPosition: VaultListPosition) {
		self.vaultAccount = vaultAccount
		self.cloudProviderAccount = cloudProviderAccount
		self.vaultListPosition = vaultListPosition
	}

	var vaultPath: CloudPath {
		return vaultAccount.vaultPath
	}

	var vaultName: String {
		return vaultAccount.vaultName
	}

	var vaultUID: String {
		return vaultAccount.vaultUID
	}

	var cloudProviderType: CloudProviderType {
		return cloudProviderAccount.cloudProviderType
	}

	var delegateAccountUID: String {
		return cloudProviderAccount.accountUID
	}

	var listPosition: Int {
		get {
			vaultListPosition.position!
		}
		set {
			vaultListPosition.position = newValue
		}
	}
}

extension VaultInfo: Equatable {
	public static func == (lhs: VaultInfo, rhs: VaultInfo) -> Bool {
		return lhs.vaultPath == rhs.vaultPath && lhs.vaultName == rhs.vaultName && lhs.vaultUID == rhs.vaultUID && lhs.cloudProviderType == rhs.cloudProviderType && lhs.delegateAccountUID == rhs.delegateAccountUID && lhs.listPosition == rhs.listPosition && lhs.vaultIsUnlocked == rhs.vaultIsUnlocked
	}
}

extension VaultInfo: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(vaultIsUnlocked)
		hasher.combine(vaultPath.path)
		hasher.combine(vaultName)
		hasher.combine(vaultUID)
		hasher.combine(cloudProviderType)
		hasher.combine(delegateAccountUID)
		hasher.combine(listPosition)
	}
}
