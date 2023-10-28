//
//  PermissionProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 19.09.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation

final class PermissionProviderMock: PermissionProvider {
	// MARK: - getPermissions

	var getPermissionsForAtCallsCount = 0
	var getPermissionsForAtCalled: Bool {
		getPermissionsForAtCallsCount > 0
	}

	var getPermissionsForAtReceivedArguments: (item: ItemMetadata, domain: NSFileProviderDomainIdentifier)?
	var getPermissionsForAtReceivedInvocations: [(item: ItemMetadata, domain: NSFileProviderDomainIdentifier)] = []
	var getPermissionsForAtReturnValue: NSFileProviderItemCapabilities!
	var getPermissionsForAtClosure: ((ItemMetadata, NSFileProviderDomainIdentifier) -> NSFileProviderItemCapabilities)?

	func getPermissions(for item: ItemMetadata, at domain: NSFileProviderDomainIdentifier) -> NSFileProviderItemCapabilities {
		getPermissionsForAtCallsCount += 1
		getPermissionsForAtReceivedArguments = (item: item, domain: domain)
		getPermissionsForAtReceivedInvocations.append((item: item, domain: domain))
		return getPermissionsForAtClosure.map({ $0(item, domain) }) ?? getPermissionsForAtReturnValue
	}

	// MARK: - getPermissionsForRootItem

	var getPermissionsForRootItemAtCallsCount = 0
	var getPermissionsForRootItemAtCalled: Bool {
		getPermissionsForRootItemAtCallsCount > 0
	}

	var getPermissionsForRootItemAtReceivedDomain: NSFileProviderDomainIdentifier?
	var getPermissionsForRootItemAtReceivedInvocations: [NSFileProviderDomainIdentifier?] = []
	var getPermissionsForRootItemAtReturnValue: NSFileProviderItemCapabilities!
	var getPermissionsForRootItemAtClosure: ((NSFileProviderDomainIdentifier?) -> NSFileProviderItemCapabilities)?

	func getPermissionsForRootItem(at domain: NSFileProviderDomainIdentifier?) -> NSFileProviderItemCapabilities {
		getPermissionsForRootItemAtCallsCount += 1
		getPermissionsForRootItemAtReceivedDomain = domain
		getPermissionsForRootItemAtReceivedInvocations.append(domain)
		return getPermissionsForRootItemAtClosure.map({ $0(domain) }) ?? getPermissionsForRootItemAtReturnValue
	}
}
