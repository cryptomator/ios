//
//  PermissionProvider.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.09.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation

public protocol PermissionProvider {
	/**
	 Returns the permission for a given `item` at a given `domain`.

	 The following restrictions can apply to any item:
	 - in case of an upload error it's only allowed to delete the item.
	 - in case of a free version only reading is allowed, except if the vault belongs to Cryptomator Hub and it has an active subscription state.

	 The following capabilities hold for files:
	 - reading
	 - adding sub items
	 - content enumerating
	 - deleting
	 - renaming
	 - reparenting

	 - Note: In case of an running upload, i.e. a creation of the folder in the cloud, the capabilities do not get restricted except if something listed above restricts all items of the vault.

	 The following capabilities hold for files:
	 - reading
	 - writing
	 - deleting
	 - renaming
	 - reparenting
	 - Note: In case of an running upload for a file it's only allowed to read the item. To prevent additional modifications.

	 */
	func getPermissions(for item: ItemMetadata, at domain: NSFileProviderDomainIdentifier) -> NSFileProviderItemCapabilities

	func getPermissionsForRootItem(at domain: NSFileProviderDomainIdentifier?) -> NSFileProviderItemCapabilities
}

private enum PermissionProviderKey: DependencyKey {
	static let liveValue: PermissionProvider = PermissionProviderImpl()
	#if DEBUG
	static let testValue: PermissionProvider = UnimplementedPermissionProvider()
	#endif
}

extension DependencyValues {
	var permissionProvider: PermissionProvider {
		get { self[PermissionProviderKey.self] }
		set { self[PermissionProviderKey.self] = newValue }
	}
}

struct PermissionProviderImpl: PermissionProvider {
	@Dependency(\.fullVersionChecker) private var fullVersionChecker
	@Dependency(\.hubRepository) private var hubRepository

	func getPermissions(for item: ItemMetadata, at domain: NSFileProviderDomainIdentifier) -> NSFileProviderItemCapabilities {
		if item.statusCode == .uploadError {
			return .allowsDeleting
		}

		let vaultID = domain.rawValue
		let hubSubscriptionState: HubSubscriptionState?
		do {
			let hubVault = try hubRepository.getHubVault(vaultID: vaultID)
			hubSubscriptionState = hubVault?.subscriptionState
		} catch {
			hubSubscriptionState = nil
			DDLogError("Failed to retrieve possible hub vault for with id: \(vaultID)")
		}

		if !fullVersionChecker.isFullVersion && hubSubscriptionState != .active {
			return FileProviderItem.readOnlyCapabilities
		}
		if item.type == .folder {
			return [.allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
		}
		if item.statusCode == .isUploading {
			return FileProviderItem.readOnlyCapabilities
		}
		return [.allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting]
	}

	func getPermissionsForRootItem(at domain: NSFileProviderDomainIdentifier?) -> NSFileProviderItemCapabilities {
		if fullVersionChecker.isFullVersion {
			return [.allowsAll]
		}
		guard let domain else {
			return FileProviderItem.readOnlyCapabilities
		}
		let vaultID = domain.rawValue
		let hubSubscriptionState: HubSubscriptionState?
		do {
			let hubVault = try hubRepository.getHubVault(vaultID: vaultID)
			hubSubscriptionState = hubVault?.subscriptionState
		} catch {
			hubSubscriptionState = nil
			DDLogError("Failed to retrieve possible hub vault for with id: \(vaultID)")
		}
		switch hubSubscriptionState {
		case .active:
			return [.allowsAll]
		case .inactive, nil:
			return FileProviderItem.readOnlyCapabilities
		}
	}
}

#if DEBUG
struct UnimplementedPermissionProvider: PermissionProvider {
	func getPermissions(for item: ItemMetadata, at domain: NSFileProviderDomainIdentifier) -> NSFileProviderItemCapabilities {
		unimplemented("\(Self.self).getPermissions", placeholder: .allowsReading)
	}

	func getPermissionsForRootItem(at domain: NSFileProviderDomainIdentifier?) -> NSFileProviderItemCapabilities {
		unimplemented("\(Self.self).getPermissionsForRootItem", placeholder: .allowsReading)
	}
}
#endif
